#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifndef CREDENTIAL_OWNER_UID
#define CREDENTIAL_OWNER_UID 0
#endif
#ifndef CREDENTIAL_DIRECTORY
#define CREDENTIAL_DIRECTORY "/var/lib/kwallet-tpm"
#endif
#ifndef SYSTEMD_CREDS
#error "The package must supply an absolute systemd-creds path"
#endif
#ifndef CREDENTIAL_POLICY
#error "The package must supply the configured PCR policy identity"
#endif
#ifndef ALLOWED_USERS
#error "The package must supply an explicit user allowlist"
#endif
#ifndef DECRYPT_TIMEOUT_MS
#define DECRYPT_TIMEOUT_MS 10000
#endif

#define SECRET_MAX 4096
#define BUFFER_SIZE 8192
#define CIPHERTEXT_MAX 65536
#define TOKEN_MARKER "kwallet-tpm-injected-token"

static const char *const allowed_users[] = ALLOWED_USERS;

static int64_t milliseconds(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return -1;
    return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static int private_file(int fd, mode_t permissions, int directory) {
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_uid != CREDENTIAL_OWNER_UID ||
        (st.st_mode & 07777) != permissions)
        return 0;
    if (directory) return S_ISDIR(st.st_mode);
    return S_ISREG(st.st_mode) && st.st_nlink == 1 &&
           st.st_size > 0 && st.st_size <= CIPHERTEXT_MAX;
}

static void release_secret(char *secret) {
    if (!secret) return;
    explicit_bzero(secret, BUFFER_SIZE);
    munlock(secret, BUFFER_SIZE);
    munmap(secret, BUFFER_SIZE);
}

/* Keep IPC descriptors above stdin/stdout/stderr before duplicating them. */
static int lift_fd(int fd) {
    if (fd < 0 || fd >= 3) return fd;
    int raised = fcntl(fd, F_DUPFD_CLOEXEC, 3);
    close(fd);
    return raised;
}

static int lift_pair(int pair[2]) {
    pair[0] = lift_fd(pair[0]);
    pair[1] = lift_fd(pair[1]);
    if (pair[0] >= 0 && pair[1] >= 0) return 1;
    if (pair[0] >= 0) close(pair[0]);
    if (pair[1] >= 0) close(pair[1]);
    return 0;
}

static int close_except(int a, int b, int c) {
    int keep[] = {a, b, c};
    for (int i = 0; i < 3; i++)
        for (int j = i + 1; j < 3; j++)
            if (keep[j] < keep[i]) {
                int swap = keep[i]; keep[i] = keep[j]; keep[j] = swap;
            }
    unsigned first = 0;
    for (int i = 0; i < 3; i++) {
        if (first < (unsigned)keep[i] &&
            close_range(first, (unsigned)keep[i] - 1, 0) != 0) return 0;
        first = (unsigned)keep[i] + 1;
    }
    return close_range(first, ~0U, 0) == 0;
}

static int send_pidfd(int socket, int pidfd) {
    char kind = 'p';
    struct iovec io = {.iov_base = &kind, .iov_len = 1};
    union { struct cmsghdr align; char bytes[CMSG_SPACE(sizeof(int))]; } control = {0};
    struct msghdr message = {.msg_iov = &io, .msg_iovlen = 1,
                            .msg_control = control.bytes,
                            .msg_controllen = sizeof(control.bytes)};
    struct cmsghdr *header = CMSG_FIRSTHDR(&message);
    header->cmsg_level = SOL_SOCKET;
    header->cmsg_type = SCM_RIGHTS;
    header->cmsg_len = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(header), &pidfd, sizeof(pidfd));
    return sendmsg(socket, &message, MSG_NOSIGNAL) == 1;
}

static int receive_control(int socket, int *pidfd, int *finished, int *success) {
    char kind = 0;
    struct iovec io = {.iov_base = &kind, .iov_len = 1};
    union { struct cmsghdr align; char bytes[CMSG_SPACE(sizeof(int))]; } control = {0};
    struct msghdr message = {.msg_iov = &io, .msg_iovlen = 1,
                            .msg_control = control.bytes,
                            .msg_controllen = sizeof(control.bytes)};
    ssize_t n = recvmsg(socket, &message, MSG_CMSG_CLOEXEC | MSG_DONTWAIT);
    if (n < 0 && (errno == EAGAIN || errno == EINTR)) return 1;
    if (n != 1) return 0;
    struct cmsghdr *header = CMSG_FIRSTHDR(&message);
    int received = -1;
    if (header && header->cmsg_level == SOL_SOCKET &&
        header->cmsg_type == SCM_RIGHTS && header->cmsg_len == CMSG_LEN(sizeof(int)))
        memcpy(&received, CMSG_DATA(header), sizeof(received));
    if (!(message.msg_flags & (MSG_CTRUNC | MSG_TRUNC)) &&
        kind == 'p' && received >= 0 && *pidfd < 0) {
        *pidfd = received;
        return 1;
    }
    if (received >= 0) close(received);
    if (!header && *pidfd >= 0 && (kind == '0' || kind == '1')) {
        *finished = 1;
        *success = kind == '0';
        return 1;
    }
    return 0;
}

static void execute_decryptor(int input, int output, const char *credential_name) {
    struct rlimit core = {0, 0};
    int null = lift_fd(open("/dev/null", O_WRONLY | O_CLOEXEC));
    if (null < 0 || setrlimit(RLIMIT_CORE, &core) != 0 ||
        dup2(input, STDIN_FILENO) < 0 || dup2(output, STDOUT_FILENO) < 0 ||
        dup2(null, STDERR_FILENO) < 0 || close_range(3, ~0U, 0) != 0)
        _exit(126);
    char *const argv[] = {SYSTEMD_CREDS, "decrypt", "--no-ask-password",
                          (char *)credential_name, "-", "-", NULL};
    char *const env[] = {"LC_ALL=C", "SYSTEMD_LOG_LEVEL=err", NULL};
    execve(SYSTEMD_CREDS, argv, env);
    _exit(127);
}

/* The worker is orphaned to init before it starts the actual TPM operation.
 * It owns/reaps the decryptor, including after PAM has reached its deadline.
 * Only a pidfd crosses back to PAM: never signal a potentially recycled PID. */
static void worker(int input, int output, int socket, const char *credential_name) {
    struct rlimit core = {0, 0};
    struct sigaction disposition = {.sa_handler = SIG_DFL};
    sigemptyset(&disposition.sa_mask);
    if (setrlimit(RLIMIT_CORE, &core) != 0 ||
        sigaction(SIGCHLD, &disposition, NULL) != 0 ||
        !close_except(input, output, socket))
        _exit(126);
    char go = 0;
    if (recv(socket, &go, 1, 0) != 1 || go != 'g') _exit(126);
    pid_t helper = fork();
    if (helper == 0) execute_decryptor(input, output, credential_name);
    close(input);
    close(output);
    if (helper < 0) _exit(126);
    int pidfd = (int)syscall(SYS_pidfd_open, helper, 0);
    if (pidfd < 0) {
        /* This worker has default SIGCHLD disposition, one child, and has not
         * waited: ownership cannot have been lost to another reaper. */
        kill(helper, SIGKILL);
    } else if (!send_pidfd(socket, pidfd)) {
        (void)syscall(SYS_pidfd_send_signal, pidfd, SIGKILL, NULL, 0);
    }
    int status = 0;
    pid_t reaped;
    do { reaped = waitpid(helper, &status, 0); } while (reaped < 0 && errno == EINTR);
    char result = reaped == helper && WIFEXITED(status) && WEXITSTATUS(status) == 0
                    ? '0' : '1';
    (void)send(socket, &result, 1, MSG_NOSIGNAL);
    if (pidfd >= 0) close(pidfd);
    close(socket);
    _exit(0);
}

static int reap_launcher(pid_t launcher, int64_t start) {
    /* The launcher only forks and exits. It is reaped before the worker is
     * permitted to open the TPM, so it cannot be the TPM-blocked process. */
    for (;;) {
        int status = 0;
        pid_t result = waitpid(launcher, &status, WNOHANG);
        if (result == launcher) return WIFEXITED(status) && WEXITSTATUS(status) == 0;
        if (result < 0) return errno == ECHILD;
        int64_t now = milliseconds();
        if (now < 0 || now - start >= DECRYPT_TIMEOUT_MS) return 0;
        (void)poll(NULL, 0, 1);
    }
}

/* Ciphertext and plaintext travel only through private file descriptors.
 * Helper diagnostics and the greeter environment never enter the handoff. */
static char *decrypt_credential(const char *username) {
    char filename[NAME_MAX + 1], credential_name[NAME_MAX + 128];
    if (snprintf(filename, sizeof(filename), "%s.cred", username) >= (int)sizeof(filename) ||
        snprintf(credential_name, sizeof(credential_name), "--name=kwallet-tpm-%s-%s",
                 username, CREDENTIAL_POLICY) >= (int)sizeof(credential_name))
        return NULL;
    int directory = open(CREDENTIAL_DIRECTORY, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (directory < 0) return NULL;
    if (!private_file(directory, 0700, 1)) { close(directory); return NULL; }
    int input = openat(directory, filename, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    close(directory);
    if (input < 0) return NULL;
    if (!private_file(input, 0600, 0)) { close(input); return NULL; }
    input = lift_fd(input);
    if (input < 0) return NULL;
    char *secret = mmap(NULL, BUFFER_SIZE, PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (secret == MAP_FAILED) { close(input); return NULL; }
    if (mlock(secret, BUFFER_SIZE) != 0 ||
        madvise(secret, BUFFER_SIZE, MADV_DONTDUMP) != 0) {
        close(input); release_secret(secret); return NULL;
    }
    int output[2], control[2];
    if (pipe2(output, O_CLOEXEC) != 0) {
        close(input); release_secret(secret); return NULL;
    }
    if (!lift_pair(output)) { close(input); release_secret(secret); return NULL; }
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, control) != 0) {
        close(input); close(output[0]); close(output[1]); release_secret(secret); return NULL;
    }
    if (!lift_pair(control)) {
        close(input); close(output[0]); close(output[1]); release_secret(secret); return NULL;
    }
    int64_t start = milliseconds();
    pid_t launcher = start < 0 ? -1 : fork();
    if (launcher == 0) {
        close(output[0]);
        close(control[0]);
        pid_t detached = fork();
        if (detached == 0) worker(input, output[1], control[1], credential_name);
        _exit(detached < 0 ? 126 : 0);
    }
    close(input);
    close(output[1]);
    close(control[1]);
    int valid = 0, pidfd = -1, finished = 0, success = 0, eof = 0;
    size_t used = 0;
    if (launcher < 0 || !reap_launcher(launcher, start) ||
        send(control[0], "g", 1, MSG_NOSIGNAL) != 1)
        goto cleanup;
    for (;;) {
        int64_t now = milliseconds();
        if (now < 0 || now - start >= DECRYPT_TIMEOUT_MS) break;
        struct pollfd fds[] = {
            {.fd = eof ? -1 : output[0], .events = POLLIN},
            {.fd = finished ? -1 : control[0], .events = POLLIN},
        };
        int remaining = DECRYPT_TIMEOUT_MS - (int)(now - start);
        int ready = poll(fds, 2, remaining);
        if (ready < 0) { if (errno == EINTR) continue; break; }
        if (fds[1].revents && !receive_control(control[0], &pidfd, &finished, &success))
            break;
        if (fds[0].revents) {
            ssize_t n = read(output[0], secret + used, SECRET_MAX + 1 - used);
            if (n > 0) {
                used += (size_t)n;
                if (used > SECRET_MAX) break;
            } else if (n == 0) eof = 1;
            else if (errno != EINTR) break;
        }
        if (eof && finished) {
            valid = success && used > 0 && !memchr(secret, '\0', used);
            break;
        }
    }
cleanup:
    if (!valid && pidfd >= 0)
        (void)syscall(SYS_pidfd_send_signal, pidfd, SIGKILL, NULL, 0);
    if (pidfd >= 0) close(pidfd);
    close(output[0]);
    close(control[0]);
    if (!valid) { release_secret(secret); return NULL; }
    secret[used] = '\0';
    return secret;
}

static int eligible(pam_handle_t *pamh, const char **username) {
    const char *service = NULL;
    if (geteuid() != CREDENTIAL_OWNER_UID ||
        pam_get_item(pamh, PAM_SERVICE, (const void **)&service) != PAM_SUCCESS ||
        !service || strcmp(service, "sddm-autologin") != 0 ||
        pam_get_item(pamh, PAM_USER, (const void **)username) != PAM_SUCCESS ||
        !*username)
        return 0;
    for (size_t i = 0; allowed_users[i]; i++)
        if (strcmp(*username, allowed_users[i]) == 0) return 1;
    return 0;
}

static void cleanup_marker(pam_handle_t *pamh, void *data, int status) {
    (void)pamh;
    (void)status;
    free(data);
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc,
                                   const char **argv) {
    (void)flags;
    const char *username = NULL;
    if (!eligible(pamh, &username)) return PAM_IGNORE;
    if (argc == 1 && strcmp(argv[0], "clear") == 0) {
        const void *data = NULL;
        if (pam_get_data(pamh, TOKEN_MARKER, &data) == PAM_SUCCESS &&
            data && *(const int *)data) {
            pam_set_item(pamh, PAM_AUTHTOK, NULL);
            *(int *)data = 0;
        }
        return PAM_IGNORE;
    }
    if (argc != 0) return PAM_IGNORE;
    const void *existing = NULL;
    if (pam_get_item(pamh, PAM_AUTHTOK, &existing) != PAM_SUCCESS || existing)
        return PAM_IGNORE;
    char *secret = decrypt_credential(username);
    if (!secret) return PAM_IGNORE;
    int *injected = calloc(1, sizeof(*injected));
    if (!injected) {
        release_secret(secret);
        return PAM_IGNORE;
    }
    if (pam_set_data(pamh, TOKEN_MARKER, injected, cleanup_marker) != PAM_SUCCESS) {
        free(injected);
        release_secret(secret);
        return PAM_IGNORE;
    }
    int result = pam_set_item(pamh, PAM_AUTHTOK, secret);
    release_secret(secret);
    if (result != PAM_SUCCESS) return PAM_IGNORE;
    *injected = 1;
    /* Used solely to select the adjacent optional wallet rule, never as an
     * authentication grant. Its default=1 branch skips that rule on failure. */
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc,
                             const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_IGNORE;
}
