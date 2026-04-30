#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

declare -gA CONFIG_VARS
CONFIG_LOADED=false

load_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: Configuration file not found: $config_file" >&2
        return 1
    fi
    
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" || -z "$value" ]] && continue
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        CONFIG_VARS["$key"]="$value"
    done < "$config_file"
    
    CONFIG_LOADED=true
}

validate_config() {
    local required_vars=(
        "CONDA_ENV_NAME"
        "CONDA_PYTHON_VERSION"
        "CONDA_PACKAGES"
        "CONDA_CHANNELS"
        "DB_HOST"
        "DB_PORT"
        "DB_PATH"
        "DB_USERNAME"
        "DB_PASSWORD"
        "DB_NAME"
        "RABBITMQ_VERSION"
        "USER_EMAIL"
        "USER_FIRSTNAME"
        "USER_LASTNAME"
        "USER_INSTITUTION"
        "PROFILE_NAME"
        "PROFILE_REPOSITORY_URI"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${CONFIG_VARS[$var]:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "ERROR: Missing required configuration variables:" >&2
        printf '  - %s\n' "${missing_vars[@]}" >&2
        return 1
    fi
    
    if [[ ! "${CONFIG_VARS[DB_PORT]}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: DB_PORT must be a valid number" >&2
        return 1
    fi
    
    if [[ ! "${CONFIG_VARS[USER_EMAIL]}" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        echo "ERROR: USER_EMAIL format is invalid" >&2
        return 1
    fi
    
    local db_path="${CONFIG_VARS[DB_PATH]}"
    local db_path_dir="$(dirname "$db_path")"
    if [[ ! -d "$db_path_dir" ]]; then
        echo "WARNING: Database path directory '$db_path_dir' does not exist" >&2
        echo "Script will attempt to create it when initializing PostgreSQL" >&2
    fi
    
    local rabbitmq_version="${CONFIG_VARS[RABBITMQ_VERSION]}"
    if [[ ! "$rabbitmq_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: RABBITMQ_VERSION must be in format X.Y.Z (e.g., 3.8.3)" >&2
        return 1
    fi
    
    return 0
}

get_config() {
    local key="$1"
    local default="${2:-}"
    echo "${CONFIG_VARS[$key]:-$default}"
}

export_config_vars() {
    for key in "${!CONFIG_VARS[@]}"; do
        export "$key"="${CONFIG_VARS[$key]}"
    done
}

print_config() {
    echo "Current Configuration:"
    for key in "${!CONFIG_VARS[@]}"; do
        if [[ "$key" == *"PASSWORD"* ]]; then
            echo "  $key=******"
        else
            echo "  $key=${CONFIG_VARS[$key]}"
        fi
    done
}

run_env_loader() {
    load_config
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to load configuration" >&2
        return 1
    fi
    
    validate_config
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Configuration validation failed" >&2
        return 1
    fi
    
    export_config_vars
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_env_loader
fi
