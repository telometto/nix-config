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

/* The encrypted input and plaintext output travel only through file descriptors.
 * Never inherit the greeter's environment or send helper diagnostics to its UI. */
static char *decrypt_credential(const char *username) {
    char filename[NAME_MAX + 1], credential_name[NAME_MAX + 32];
    if (snprintf(filename, sizeof(filename), "%s.cred", username) >= (int)sizeof(filename) ||
        snprintf(credential_name, sizeof(credential_name), "--name=kwallet-tpm-%s",
                 username) >= (int)sizeof(credential_name))
        return NULL;
    int directory = open(CREDENTIAL_DIRECTORY, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (directory < 0) return NULL;
    if (!private_file(directory, 0700, 1)) {
        close(directory);
        return NULL;
    }
    int input = openat(directory, filename, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    close(directory);
    if (input < 0) return NULL;
    if (!private_file(input, 0600, 0)) {
        close(input);
        return NULL;
    }
    char *secret = mmap(NULL, BUFFER_SIZE, PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (secret == MAP_FAILED) {
        close(input);
        return NULL;
    }
    if (mlock(secret, BUFFER_SIZE) != 0 ||
        madvise(secret, BUFFER_SIZE, MADV_DONTDUMP) != 0) {
        close(input);
        release_secret(secret);
        return NULL;
    }
    int output[2];
    if (pipe2(output, O_CLOEXEC) != 0) {
        close(input);
        release_secret(secret);
        return NULL;
    }
    int64_t start = milliseconds();
    if (start < 0) {
        close(input);
        close(output[0]);
        close(output[1]);
        release_secret(secret);
        return NULL;
    }
    pid_t child = fork();
    if (child == 0) {
        struct rlimit core = {0, 0};
        int null = open("/dev/null", O_WRONLY | O_CLOEXEC);
        if (null < 0 || setrlimit(RLIMIT_CORE, &core) != 0 ||
            dup2(input, STDIN_FILENO) < 0 ||
            dup2(output[1], STDOUT_FILENO) < 0 ||
            dup2(null, STDERR_FILENO) < 0 || close_range(3, ~0U, 0) != 0)
            _exit(126);
        char *const argv[] = {SYSTEMD_CREDS, "decrypt", "--no-ask-password",
                              credential_name, "-", "-", NULL};
        char *const env[] = {"LC_ALL=C", "SYSTEMD_LOG_LEVEL=err", NULL};
        execve(SYSTEMD_CREDS, argv, env);
        _exit(127);
    }
    close(input);
    close(output[1]);
    if (child < 0) {
        close(output[0]);
        release_secret(secret);
        return NULL;
    }
    size_t used = 0;
    int eof = 0, finished = 0, status = 0, valid = 0;
    while (1) {
        int64_t now = milliseconds();
        if (now < 0 || now - start >= DECRYPT_TIMEOUT_MS) break;
        struct pollfd pfd = {.fd = eof ? -1 : output[0], .events = POLLIN};
        int remaining = DECRYPT_TIMEOUT_MS - (int)(now - start);
        int ready = poll(&pfd, 1, remaining > 10 ? 10 : remaining);
        if (ready < 0 && errno != EINTR) break;
        if (ready > 0 && pfd.revents) {
            ssize_t n = read(output[0], secret + used, SECRET_MAX + 1 - used);
            if (n > 0) {
                used += (size_t)n;
                if (used > SECRET_MAX) break;
            } else if (n == 0) {
                eof = 1;
            } else if (errno != EINTR) {
                break;
            }
        }
        if (!finished) {
            pid_t result = waitpid(child, &status, WNOHANG);
            if (result == child) finished = 1;
            else if (result < 0 && errno != EINTR) break;
        }
        if (eof && finished) {
            valid = WIFEXITED(status) && WEXITSTATUS(status) == 0 &&
                    used > 0 && !memchr(secret, '\0', used);
            break;
        }
    }
    close(output[0]);
    if (!finished) {
        kill(child, SIGKILL);
        while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
    }
    if (!valid) {
        release_secret(secret);
        return NULL;
    }
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
