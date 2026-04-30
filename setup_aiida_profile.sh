#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$SCRIPT_DIR" == */scripts ]]; then
    PROJECT_ROOT="$SCRIPT_DIR"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

if [[ ! -f "$PROJECT_ROOT/scripts/01-env_loader.sh" ]]; then
    if [[ -f "$SCRIPT_DIR/../scripts/01-env_loader.sh" ]]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    elif [[ -f "$SCRIPT_DIR/scripts/01-env_loader.sh" ]]; then
        PROJECT_ROOT="$SCRIPT_DIR"
    fi
fi

if [[ -f "$PROJECT_ROOT/scripts/01-env_loader.sh" ]]; then
    source "$PROJECT_ROOT/scripts/01-env_loader.sh"
else
    echo "ERROR: Cannot find scripts directory. Checked:" >&2
    echo "  - $PROJECT_ROOT/scripts/01-env_loader.sh" >&2
    echo "  - $SCRIPT_DIR/scripts/01-env_loader.sh" >&2
    exit 1
fi

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

show_config() {
    echo ""
    echo "Configuration Summary:"
    echo "---------------------"
    echo "  Conda Environment:"
    echo "    - Name: ${CONFIG_VARS[CONDA_ENV_NAME]:-N/A}"
    echo "    - Python Version: ${CONFIG_VARS[CONDA_PYTHON_VERSION]:-N/A}"
    echo "    - Packages: ${CONFIG_VARS[CONDA_PACKAGES]:-N/A}"
    echo ""
    echo "  Database:"
    echo "    - Host: ${CONFIG_VARS[DB_HOST]:-N/A}"
    echo "    - Port: ${CONFIG_VARS[DB_PORT]:-N/A}"
    echo "    - Data Path: ${CONFIG_VARS[DB_PATH]:-N/A}"
    echo "    - Username: ${CONFIG_VARS[DB_USERNAME]:-N/A}"
    echo "    - Database: ${CONFIG_VARS[DB_NAME]:-N/A}"
    echo ""
    echo "  RabbitMQ:"
    echo "    - Version: ${CONFIG_VARS[RABBITMQ_VERSION]:-N/A}"
    echo ""
    echo "  User:"
    echo "    - Email: ${CONFIG_VARS[USER_EMAIL]:-N/A}"
    echo "    - Name: ${CONFIG_VARS[USER_FIRSTNAME]:-N/A} ${CONFIG_VARS[USER_LASTNAME]:-N/A}"
    echo "    - Institution: ${CONFIG_VARS[USER_INSTITUTION]:-N/A}"
    echo ""
    echo "  AiiDA Profile:"
    echo "    - Name: ${CONFIG_VARS[PROFILE_NAME]:-N/A}"
    echo "    - Repository: ${CONFIG_VARS[PROFILE_REPOSITORY_URI]:-N/A}"
    echo ""
}

main() {
    echo ""
    echo "AiiDA Profile Setup"
    echo "==================="
    echo ""

    load_config
    export_config_vars
    show_config

    echo ""
    read -p "Continue with setup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user."
        exit 0
    fi

    local overall_status=0
    local start_time=$(date +%s)

    bash "$PROJECT_ROOT/scripts/init_aiida.sh" || overall_status=1

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    if [ $overall_status -eq 0 ]; then
        echo "✓ Setup completed successfully! (${duration}s)"
        echo ""
        echo "Next steps:"
        echo "  1. conda activate ${CONDA_ENV_NAME:-aiida_test}"
        echo "  2. verdi status"
    else
        echo "✗ Setup completed with errors (${duration}s)"
        echo "Please review the errors above."
    fi
    echo ""

    return $overall_status
}

main "$@"
