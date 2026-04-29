#!/bin/bash

_common_script="${BASH_SOURCE[0]}"
_COMMON_DIR="$(cd "$(dirname "$_common_script")" && pwd)"
_PROJECT_DIR="$(cd "$_COMMON_DIR/.." && pwd)"

if [ -z "$PROJECT_DIR" ]; then
    export PROJECT_DIR="$_PROJECT_DIR"
fi

if [ -z "$CONFIG_FILE" ]; then
    export CONFIG_FILE="$_PROJECT_DIR/config.env"
fi

unset _common_script
unset _COMMON_DIR
unset _PROJECT_DIR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_skip() { echo -e "${CYAN}[SKIP]${NC} $1"; }

report_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

report_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "  ${GREEN}[OK]${NC}   $message"
            ;;
        "WARN")
            echo -e "  ${YELLOW}[WARN]${NC} $message"
            ;;
        "FAIL")
            echo -e "  ${RED}[FAIL]${NC} $message"
            ;;
        "SKIP")
            echo -e "  ${CYAN}[SKIP]${NC} $message"
            ;;
        "DONE")
            echo -e "  ${GREEN}[DONE]${NC} $message"
            ;;
    esac
}

report_item() {
    echo -e "  ${CYAN}•${NC} $1"
}

load_env() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Warning: Config file not found: $CONFIG_FILE" >&2
        echo "Creating default config file..." >&2
        create_default_config
    fi

    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]]; then
                continue
            fi

            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ -n "$key" ]]; then
                export "$key=$value"
            fi
        done < "$CONFIG_FILE"
    fi
}

create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# ==============================================================================
# AiiDA Profile Configuration (Default)
# ==============================================================================

# Conda Environment
CONDA_ENV_NAME=aiida
CONDA_PYTHON_VERSION=3.10
CONDA_PACKAGES=aiida-core aiida-vasp
CONDA_CHANNELS=conda-forge

# Database Configuration
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=aiida_user
DB_PASSWORD=123
DB_NAME=aiida_db
DB_DATA_DIR=~/mylocal_db

# RabbitMQ Configuration
RABBITMQ_HOST=127.0.0.1
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=aiida
RABBITMQ_PASSWORD=123
RABBITMQ_VHOST=aiida

# User Information
USER_EMAIL=your.email@example.com
USER_FIRSTNAME=YourFirstName
USER_LASTNAME=YourLastName
USER_INSTITUTION=YourInstitution

# AiiDA Profile Settings
PROFILE_NAME=aiida_profile
PROFILE_REPOSITORY_URI=file:///tmp/aiida_repository
EOF
    echo "Created default config at: $CONFIG_FILE" >&2
}

show_env() {
    echo ""
    echo "=========================================="
    echo "Configuration Summary"
    echo "=========================================="
    echo ""
    echo "Config File: $CONFIG_FILE"
    echo ""
    echo "Conda:"
    echo "  Env Name: ${CONDA_ENV_NAME:-aiida} (default)"
    echo "  Python Version: ${CONDA_PYTHON_VERSION:-3.10} (default)"
    [ -n "$CONDA_PACKAGES" ] && echo "  Packages: $CONDA_PACKAGES"
    [ -n "$CONDA_CHANNELS" ] && echo "  Channels: $CONDA_CHANNELS"
    echo ""
    echo "Database:"
    echo "  Host: ${DB_HOST:-127.0.0.1} (default)"
    echo "  Port: ${DB_PORT:-5432} (default)"
    echo "  Username: ${DB_USERNAME:-aiida_user} (default)"
    echo "  Password: [hidden]"
    echo "  Database: ${DB_NAME:-aiida_db} (default)"
    echo "  Data Dir: ${DB_DATA_DIR:-$HOME/mylocal_db} (default)"
    echo ""
    echo "RabbitMQ:"
    echo "  Host: ${RABBITMQ_HOST:-127.0.0.1} (default)"
    echo "  Port: ${RABBITMQ_PORT:-5672} (default)"
    echo "  Username: ${RABBITMQ_USERNAME:-aiida} (default)"
    echo "  Password: [hidden]"
    echo "  VHost: ${RABBITMQ_VHOST:-aiida} (default)"
    echo ""
    echo "User:"
    echo "  Email: ${USER_EMAIL:-your.email@example.com} (default)"
    echo "  Name: ${USER_FIRSTNAME:-YourFirstName} ${USER_LASTNAME:-YourLastName} (default)"
    echo "  Institution: ${USER_INSTITUTION:-YourInstitution} (default)"
    echo ""
    echo "Profile:"
    echo "  Name: ${PROFILE_NAME:-aiida_profile} (default)"
    [ -n "$PROFILE_REPOSITORY_URI" ] && echo "  Repository: $PROFILE_REPOSITORY_URI"
    echo "=========================================="
    echo ""
}

load_config() {
    load_env
}

show_config() {
    show_env
}

get_conda_create_cmd() {
    local env_name="${CONDA_ENV_NAME:-aiida}"
    local python_version="${CONDA_PYTHON_VERSION:-3.10}"
    local channels="${CONDA_CHANNELS:-conda-forge}"
    local packages="${CONDA_PACKAGES:-aiida-core aiida-vasp}"

    local cmd="conda create -n $env_name python=$python_version -c $channels"
    for pkg in $packages; do
        cmd="$cmd $pkg"
    done

    echo "$cmd"
}
