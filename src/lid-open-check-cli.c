#include <ctype.h>
#include <errno.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define CONFIG_FILE      "/etc/pam-lid-open-check.conf"
#define PAM_PROFILE_DEST "/usr/share/pam-configs/pam-lid-open-check"
#define MODULE_FILENAME  "pam-lid-open-check.so"
#define PROFILE_FILENAME "pam-lid-open-check-config"

// ====================================================
// Helpers
// ====================================================

static int write_config(char *option, char *val){
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (!fp) {
        fprintf(stderr, "Error: cannot open %s: %s\n", CONFIG_FILE, strerror(errno));
        return -1;
    }

    int optionLen = strlen(option);

    char lines[128][256];
    int count = 0;
    while (count < 128 && fgets(lines[count], sizeof(lines[count]), fp))
        count++;
    fclose(fp);

    int found = 0;
    for (int i = 0; i < count; i++) {
        char *p = lines[i];
        while (*p && isspace((unsigned char)*p)) p++;
        if (strncmp(p, option, optionLen) == 0 && strchr(p, '=')) {
            snprintf(lines[i], sizeof(lines[i]), " %s = %s\n", option, val);
            found = 1;
            break;
        }
    }
    if (!found) {
        if (count >= 128) {
            fprintf(stderr, "Error: config file has too many lines\n");
            return -1;
        }
        snprintf(lines[count], sizeof(lines[count]), "%s = %s\n", option, val);
        count++;
    }

    fp = fopen(CONFIG_FILE, "w");
    if (!fp) {
        fprintf(stderr, "Error: cannot write %s: %s\n", CONFIG_FILE, strerror(errno));
        return -1;
    }
    for (int i = 0; i < count; i++)
        fputs(lines[i], fp);
    fclose(fp);
    return 0;
}

static char* read_config(char* option){
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (!fp) {
        printf("Error: Failed to open config file");
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

static int read_enabled(char *option) {
    char *value = read_config(option);

    int enabled = -1;

    if (value) {
        value++;
        while (*value && isspace(*value)) value++;
        
        if (strncasecmp(value, "true", 4) == 0 ||
            strncasecmp(value, "1", 1) == 0) {
            enabled = 1;
        } else if ( strncasecmp(value, "false", 5) == 0 ||
                    strncasecmp(value, "0", 1) == 0) {
            enabled = 0;
        }
    }
    return enabled;
}

// ====================================================
// Config read/write
// ====================================================

static int write_enabled(int enabled) {
    char *val = enabled ? "true" : "false";

    return write_config("enabled", val);
}

static int write_debug(int enabled) {
    char *val = enabled ? "true" : "false";

    return write_config("debug", val);
}

static int read_lid() {
    char *value = read_config("debug-state");

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

static int write_lid(int state) {
    char *val = state ? "closed" : "open";

    return write_config("debug-state", val);
}

// ====================================================
// Commands
// ====================================================

static int cmd_status(void) {
    int enabled = read_enabled("enabled");
    if (enabled == -1) {
        printf("Warning: 'enabled' config option missing\n");
        return 1;
    }

    int debug = read_enabled("debug");
    if (debug == -1) {
        printf("Warning: 'debug' config option missing\n");
        return 1;
    }

    int state = read_lid();
    if (state == -1) {
        printf("Warning: 'debug-state' config option missing\n");
        return 1;
    }

    printf("pam-lid-open-check - Pam Module: %s\n", enabled ? "enabled" : "disabled");
    printf("pam-lid-open-check - debug mode: %s\n", debug ? "enabled" : "disabled");
    printf("pam-lid-open-check - debug state: %s\n", state ? "closed" : "open");

    return 0;
}

static int cmd_enable(void) {
    if (write_enabled(1) != 0) return 1;
    printf("pam-lid-open-check: enabled\n");
    return 0;
}

static int cmd_disable(void) {
    if (write_enabled(0) != 0) return 1;
    printf("pam-lid-open-check: disabled\n");
    return 0;
}

// ==========
// Debug
static int cmd_debug_enable(void) {
    if (write_debug(1) != 0) return 1;
    printf("pam-lid-open-check: debug enabled\n");
    return 0;
}

static int cmd_debug_disable(void) {
    if (write_debug(0) != 0) return 1;
    printf("pam-lid-open-check: debug disabled\n");
    return 0;
}

static int cmd_lid_close(void) {
    if (write_lid(1) != 0) return 1;
    printf("pam-lid-open-check: debug lid-state: closed\n");
    return 0;
}

static int cmd_lid_open(void) {
    if (write_lid(0) != 0) return 1;
    printf("pam-lid-open-check: debug lid-state: open\n");
    return 0;
}

static void print_usage(const char *prog) {
    printf("Usage: %s <command>\n\n", prog);
    printf("Commands:\n");
    printf("  status     Shows if lid-open-check is enabled or disabled\n");
    printf("  enable     Enables lid-open-check PAM module\n");
    printf("  disable    Disables lid-open-check PAM module\n");
    printf("\n");
    printf("Debug Commands:\n");
    printf("  debug enable           Enables debug logging\n");
    printf("  debug disable          Disables debug logging\n");
    printf("  state open             Simulate lid opened (debug)\n");
    printf("  state closed           Simulate lid closed (debug)\n");
    printf("\n");
    printf("Licence: MIT\n");
    printf("GitHub: https://github.com/Ryan-Diazz\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    const char *cmd = argv[1];

    if (strcmp(cmd, "status") == 0)
        return cmd_status();

    if (strcmp(cmd, "enable") == 0)
        return cmd_enable();

    if (strcmp(cmd, "disable") == 0)
        return cmd_disable();

    if (strcmp(cmd, "help") == 0) {
        print_usage(argv[0]);
        return 0;
    }

    if (strcmp(cmd, "debug") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Missing debug action.\n\n");
            print_usage(argv[0]);
            return 1;
        }

        if (strcmp(argv[2], "enable") == 0)
            return cmd_debug_enable();

        if (strcmp(argv[2], "disable") == 0)
            return cmd_debug_disable();

        fprintf(stderr, "Unknown debug action: %s\n\n", argv[2]);
        print_usage(argv[0]);
        return 1;
    }

    if (strcmp(cmd, "state") == 0) {
        if (argc < 3) {
            fprintf(stderr, "Missing state.\n\n");
            print_usage(argv[0]);
            return 1;
        }

        if (strcmp(argv[2], "open") == 0)
            return cmd_lid_open();

        if (strcmp(argv[2], "closed") == 0)
            return cmd_lid_close();

        fprintf(stderr, "Unknown state: %s\n\n", argv[2]);
        print_usage(argv[0]);
        return 1;
    }

    fprintf(stderr, "Unknown command: %s\n\n", cmd);
    print_usage(argv[0]);
    return 1;
}