/* Test-only PAM module. Never packaged with or selected by the production
 * runtime: tests point a private compositor's QML copy at a private PAM dir.
 * No accounts, passwords, fprintd or physical devices are consulted.
 */
#include <security/pam_appl.h>
#include <security/pam_ext.h>
#include <security/pam_modules.h>
#include <string.h>

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)flags; (void)argc; (void)argv;
    const char *token = NULL;
    int result = pam_get_authtok(pamh, PAM_AUTHTOK, &token, "Test-only token: ");
    if (result != PAM_SUCCESS) return result;
    return token && strcmp(token, "QYLOCK_TEST_ONLY_NOT_A_REAL_PASSWORD") == 0 ? PAM_SUCCESS : PAM_AUTH_ERR;
}
PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_SUCCESS;
}
PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_SUCCESS;
}
