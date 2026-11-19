#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifdef PAM_WAIT_FIXTURE
pid_t __real_waitpid(pid_t pid, int *status, int options);
pid_t __wrap_waitpid(pid_t pid, int *status, int options) {
    if (options == 0) {
        struct timespec delay = {2, 0};
        nanosleep(&delay, NULL);
    }
    pid_t result = __real_waitpid(pid, status, options);
    if (options == 0 && result > 0) {
        int fd = open(REAP_MARKER_PATH, O_WRONLY | O_CREAT | O_CLOEXEC, 0600);
        if (fd >= 0) {
            if (write(fd, "reaped", 6) != 6) _exit(125);
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
