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

#define CONFIG_FILE "/etc/pam-lid-open-check.conf"
#define LID_STATE_PATTERN "/proc/acpi/button/lid/*/state"

// ====================================================
// Helper Functions
// ====================================================

/*
 * Reads the config file for an option line and returns the value after the = if the line is found,
 * Default return is "".
*/
static char* read_config(char* path, char* option, pam_handle_t *pamh){
    FILE *fp = fopen(path, "r");
    if (!fp) {
        pam_syslog(pamh, LOG_ERR, "pam-lid-open-check: Failed to open config file");
        return "";
    }

    char line[256];
    while (fgets(line, sizeof(line), fp) != NULL) {
        /* Skip comments and empty lines */
        if (line[0] == '#' || line[0] == '\n') {
            continue;
        }

        /* Trim whitespace */
        char *start = line;
        while (*start && isspace(*start)) start++;
        char *end = start + strlen(start) - 1;
        while (end > start && isspace(*end)) *end-- = '\0';

        char optionLenght = strlen(option);
        /* Check for enabled setting */
        if (strncmp(start, option, optionLenght) == 0) {
            return strchr(start, '=');
        }
    }

    fclose(fp);
    return "";
}

/**
 * Check if the module is enabled in config file
 * Returns 1 if enabled, 0 if disabled.
 * Default enabled.
 */
static int config_is_enabled(char *option, pam_handle_t *pamh) {
    int enabled = 1; /* Default to enabled */
    
    char* value = read_config(CONFIG_FILE, option, pamh);
    if (value) {
        value++;
        while (*value && isspace(*value)) value++;
        
        if (strncasecmp(value, "yes", 3) == 0 || 
            strncasecmp(value, "true", 4) == 0 ||
            strncasecmp(value, "1", 1) == 0) {
            enabled = 1;
        } else if (strncasecmp(value, "no", 2) == 0 || 
                    strncasecmp(value, "false", 5) == 0 ||
                    strncasecmp(value, "0", 1) == 0) {
            enabled = 0;
        }
    }
    return enabled;
}

static int config_debug_state(char *option, pam_handle_t *pamh) {
    char *value = read_config(CONFIG_FILE, "debug-state", pamh);

    int state = -1;

    if (value) {
        value++;
        while (*value && isspace(*value)) value++;
        
        if (strncasecmp(value, "closed", 5) == 0) {
            state = 1;
        } else if ( strncasecmp(value, "open", 4) == 0) {
            state = 0;
        }
    }
    return state;
}

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
                   "pam-lid-open-check: No lid device found, treating as open");
        return -1;
    }

    /* Open the first lid state file found */
    FILE *fp = fopen(globbuf.gl_pathv[0], "r");
    globfree(&globbuf);

    if (!fp) {
        pam_syslog(pamh, LOG_ERR, "pam-lid-open-check: Failed to open lid state file");
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

/* PAM module function for pam-lid-open-check */
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

    // Check if module is enabled
    // ===================
    if (!config_is_enabled("enabled", pamh)) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: Module disabled");
        }
        return PAM_IGNORE;
    }
    
    // Check lid state
    // ===================
    if (config_is_enabled("debug", pamh)) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: debug enabled");
        }
        lid_state = config_debug_state("debug-state", pamh);
    } else {
        pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: debug disabled");
        lid_state = check_lid_state(pamh);
    }

    // Debug log of the lid state
    if (debug) {
        char* stateStr = (lid_state == 1) ? "closed" : (lid_state == 0) ? "open" : "not found";
        pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: Lid state = %s", stateStr);
    }

    // No Lid
    // ===================
    if (lid_state == -1) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: Returning PAM_IGNORE (no lid found)");
        }
        return PAM_IGNORE;
    }

    // Closed Lid
    // ===================
    if (lid_state == 1) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: Lid closed, returning PAM_SUCCESS");
        }
        return PAM_SUCCESS;
    }

    // Open Lid
    // ===================
    if (lid_state == 0) {
        if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: Lid open, returning PAM_IGNORE");
        }
        return PAM_IGNORE;
    }

    // Default Return
    // ===================
    if (debug) {
            pam_syslog(pamh, LOG_DEBUG, "pam-lid-open-check: Default returning PAM_IGNORE");
    }
    return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}