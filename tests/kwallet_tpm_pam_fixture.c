#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifdef PAM_DEADLINE_FIXTURE
ssize_t __real_send(int socket, const void *buffer, size_t length, int flags);
ssize_t __wrap_send(int socket, const void *buffer, size_t length, int flags) {
    ssize_t sent = __real_send(socket, buffer, length, flags);
    if (sent == 1 && length == 1 && *(const char *)buffer == 'g') {
        /* Let the worker queue its pidfd without receiving it, then resume
         * PAM only after its deadline. No production timing hook is needed. */
        struct pollfd pending = {.fd = socket, .events = POLLIN};
        int ready;
        do { ready = poll(&pending, 1, 1000); } while (ready < 0 && errno == EINTR);
        if (ready != 1 || !(pending.revents & POLLIN)) _exit(125);
        struct timespec delay = {0, 300000000};
        while (nanosleep(&delay, &delay) < 0 && errno == EINTR) {}
    }
    return sent;
}
#endif

#if defined(PAM_WAIT_FIXTURE) || defined(PAM_DEADLINE_FIXTURE)
pid_t __real_waitpid(pid_t pid, int *status, int options);
pid_t __wrap_waitpid(pid_t pid, int *status, int options) {
#ifdef PAM_WAIT_FIXTURE
    if (options == 0) {
        struct timespec delay = {2, 0};
        nanosleep(&delay, NULL);
    }
#endif
    pid_t result = __real_waitpid(pid, status, options);
    if (options == 0 && result > 0) {
        int fd = open(REAP_MARKER_PATH, O_WRONLY | O_CREAT | O_CLOEXEC, 0600);
        if (fd >= 0) {
#ifdef PAM_DEADLINE_FIXTURE
            const char *outcome = WIFSIGNALED(*status) && WTERMSIG(*status) == SIGKILL
                                      ? "killed" : "exited";
#else
            const char *outcome = "reaped";
#endif
            size_t length = strlen(outcome);
            if (write(fd, outcome, length) != (ssize_t)length) _exit(125);
            close(fd);
        }
    }
    return result;
}
#elif defined(PAM_FIXTURE_MODULE)
PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc,
                                   const char **argv) {
    (void)flags;
    if (argc != 1) return PAM_IGNORE;
    if (strcmp(argv[0], "seed") == 0)
        return pam_set_item(pamh, PAM_AUTHTOK, "preexisting-token");
    const char *token = NULL;
    pam_get_item(pamh, PAM_AUTHTOK, (const void **)&token);
    if (strcmp(argv[0], "wallet") == 0) {
        pam_putenv(pamh, token && strcmp(token, "fixture-only-password") == 0
                            ? "FIXTURE_SEEN=yes" : "FIXTURE_SEEN=bad");
    } else {
        pam_putenv(pamh, !token ? "FIXTURE_AFTER=clear"
                               : strcmp(token, "preexisting-token") == 0
                                     ? "FIXTURE_AFTER=existing"
                                     : "FIXTURE_AFTER=leaked");
    }
    return PAM_IGNORE;
}
PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc,
                             const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_IGNORE;
}
#else
static int conversation(int n, const struct pam_message **messages,
                        struct pam_response **responses, void *data) {
    (void)n; (void)messages; (void)responses;
    (*(int *)data)++;
    return PAM_CONV_ERR;
}
int main(int argc, char **argv) {
    if (argc != 4) return 2;
    int prompts = 0;
    const struct pam_conv conv = { conversation, &prompts };
    pam_handle_t *pamh = NULL;
    int result = pam_start_confdir(argv[2], argv[3], &conv, argv[1], &pamh);
    if (result != PAM_SUCCESS) return 3;
    result = pam_authenticate(pamh, 0);
    const char *seen = pam_getenv(pamh, "FIXTURE_SEEN");
    const char *after = pam_getenv(pamh, "FIXTURE_AFTER");
    printf("result=%d prompts=%d seen=%s after=%s\n", result, prompts,
           seen ? seen : "-", after ? after : "-");
    pam_end(pamh, result);
    return 0;
}
#endif
