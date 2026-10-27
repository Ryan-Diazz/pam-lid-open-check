#include <asm-generic/errno-base.h>
#include <ctype.h>
#include <security/_pam_types.h>
#define PAM_SM_AUTH
#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <glob.h>
#include <syslog.h>

#define LID_STATE_PATTERN "/proc/acpi/button/lid/*/state"

// ====================================================
// Helper Functions
// ====================================================

/**
 * Find and read the lid state file
 * Returns: 1 if closed, 0 if open, -1 if not found
 */
static int check_lid_state(pam_handle_t *pamh) {
    glob_t globbuf;
    int ret;

    ret = glob(LID_STATE_PATTERN, 0, NULL, &globbuf);
    
    if (ret != 0 || globbuf.gl_pathc == 0) {
        /* No lid found (desktop machine) */
        globfree(&globbuf);
        pam_syslog(pamh, LOG_DEBUG, 
                   "pam_lidcheck: No lid device found, treating as open");
        return -1;
    }

    /* Open the first lid state file found */
    FILE *fp = fopen(globbuf.gl_pathv[0], "r");
    globfree(&globbuf);

    if (!fp) {
        pam_syslog(pamh, LOG_ERR, "pam_lidcheck: Failed to open lid state file");
        return -1;
    }

    char line[256];
    int is_closed = -1;

    if (fgets(line, sizeof(line), fp) != NULL) {
        if (strstr(line, "closed") != NULL) {
            is_closed = 1;  /* Lid is closed */
        } else if (strstr(line, "open") != NULL) {
            is_closed = 0;  /* Lid is open */
        }
    }

    fclose(fp);
    return is_closed;
}

// ====================================================
// PAM Functions
// ====================================================

/* PAM module function for pam_lidcheck */
PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    int lid_state;
    int debug = 0;

    // Check for debug flag
    // ===================
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "debug") == 0) {
            debug = 1;
        }
    }
    
    // Check lid state
    // ===================
    lid_state = check_lid_state(pamh);

    if (debug) {
        char* stateStr = (lid_state == 1) ? "closed" : (lid_state == 0) ? "open" : "not found";
        pam_syslog(pamh, LOG_DEBUG, "pam_lidcheck: Lid state = %s", stateStr);
    }

    // No Lid
    // ===================
    if (lid_state == -1) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam_lidcheck: Returning PAM_IGNORE (no lid found)");
        }
        return PAM_IGNORE;
    }

    // Closed Lid
    // ===================
    if (lid_state == 1) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam_lidcheck: Lid closed, returning PAM_SUCCESS");
        }
        return PAM_SUCCESS;
    }

    // Open Lid
    // ===================
    if (lid_state == 0) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam_lidcheck: Lid open, returning PAM_IGNORE");
        }
        return PAM_IGNORE;
    }

    // Default Return
    // ===================
    if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam_lidcheck: returning PAM_IGNORE (default return)");
    }
    return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}