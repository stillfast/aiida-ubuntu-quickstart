#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01-env_loader.sh"
source "${SCRIPT_DIR}/03-db_mq_config.sh"

check_aiida_installed() {
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    if command -v verdi &> /dev/null; then
        conda deactivate
        return 0
    else
        conda deactivate
        return 1
    fi
}

check_profile_exists() {
    local profile_name="${CONFIG_VARS[PROFILE_NAME]}"
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    if verdi profile list 2>/dev/null | grep -qE "^\*?\s*$profile_name\s*$"; then
        conda deactivate
        return 0
    else
        conda deactivate
        return 1
    fi
}

verify_profile_config() {
    local profile_name="${CONFIG_VARS[PROFILE_NAME]}"
    
    echo "Verifying AiiDA profile: $profile_name"
    
    if ! check_profile_exists; then
        echo "Profile '$profile_name' does not exist"
        return 1
    fi
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    local profile_info=$(verdi profile show "$profile_name" 2>/dev/null)
    
    local db_host=$(echo "$profile_info" | grep "^[[:space:]]*database_hostname:" | awk '{print $2}' | tr -d "'" | xargs)
    local db_port=$(echo "$profile_info" | grep "^[[:space:]]*database_port:" | awk '{print $2}' | xargs)
    local db_name=$(echo "$profile_info" | grep "^[[:space:]]*database_name:" | awk '{print $2}' | xargs)
    
    conda deactivate
    
    local config_db_host="${CONFIG_VARS[DB_HOST]}"
    local config_db_port="${CONFIG_VARS[DB_PORT]}"
    local config_db_name="${CONFIG_VARS[DB_NAME]}"
    
    local mismatches=()
    
    if [[ "$db_host" != "$config_db_host" ]]; then
        mismatches+=("DB Host: expected '$config_db_host', got '$db_host'")
    fi
    
    if [[ "$db_port" != "$config_db_port" ]]; then
        mismatches+=("DB Port: expected '$config_db_port', got '$db_port'")
    fi
    
    if [[ "$db_name" != "$config_db_name" ]]; then
        mismatches+=("DB Name: expected '$config_db_name', got '$db_name'")
    fi
    
    if [[ ${#mismatches[@]} -gt 0 ]]; then
        echo "Profile configuration mismatches found:"
        printf '  - %s\n' "${mismatches[@]}"
        return 1
    fi
    
    echo "Profile configuration is correct"
    return 0
}

setup_aiida_user() {
    echo "Setting up AiiDA user..."
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    local email="${CONFIG_VARS[USER_EMAIL]}"
    local firstname="${CONFIG_VARS[USER_FIRSTNAME]}"
    local lastname="${CONFIG_VARS[USER_LASTNAME]}"
    local institution="${CONFIG_VARS[USER_INSTITUTION]}"
    
    if verdi user list 2>/dev/null | grep -q "$email"; then
        echo "User with email '$email' already exists"
    else
        verdi user create \
            --email "$email" \
            --first-name "$firstname" \
            --last-name "$lastname" \
            --institution "$institution" \
            --profile "${CONFIG_VARS[PROFILE_NAME]}"
        
        if [[ $? -eq 0 ]]; then
            echo "User created successfully"
        else
            echo "Failed to create user" >&2
            conda deactivate
            return 1
        fi
    fi
    
    conda deactivate
    return 0
}

create_aiida_profile() {
    local profile_name="${CONFIG_VARS[PROFILE_NAME]}"
    local repository_uri="${CONFIG_VARS[PROFILE_REPOSITORY_URI]}"
    local db_host="${CONFIG_VARS[DB_HOST]}"
    local db_port="${CONFIG_VARS[DB_PORT]}"
    local db_username="${CONFIG_VARS[DB_USERNAME]}"
    local db_password="${CONFIG_VARS[DB_PASSWORD]}"
    local db_name="${CONFIG_VARS[DB_NAME]}"
    local email="${CONFIG_VARS[USER_EMAIL]}"
    local firstname="${CONFIG_VARS[USER_FIRSTNAME]}"
    local lastname="${CONFIG_VARS[USER_LASTNAME]}"
    local institution="${CONFIG_VARS[USER_INSTITUTION]}"
    
    echo "Creating AiiDA profile: $profile_name"
    echo "Repository URI: $repository_uri"
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    export PGPASSWORD="$db_password"
    
    verdi profile setup core.psql_dos \
        -n \
        --profile-name "$profile_name" \
        --set-as-default \
        --email "$email" \
        --first-name "$firstname" \
        --last-name "$lastname" \
        --institution "$institution" \
        --use-rabbitmq \
        --database-username "$db_username" \
        --database-password "$db_password" \
        --database-name "$db_name" \
        --database-engine postgresql_psycopg \
        --database-hostname "$db_host" \
        --database-port "$db_port" \
        --repository-uri "$repository_uri"
    
    local setup_status=$?
    conda deactivate
    unset PGPASSWORD
    
    if [[ $setup_status -eq 0 ]]; then
        echo "AiiDA profile created successfully"
        return 0
    else
        echo "Failed to create AiiDA profile" >&2
        return 1
    fi
}

configure_aiida_profile() {
    echo "Configuring AiiDA profile..."
    
    if ! check_aiida_installed; then
        echo "ERROR: AiiDA is not installed in the conda environment" >&2
        return 1
    fi
    
    if ! check_postgres_running; then
        echo "ERROR: PostgreSQL is not running. Please run db_mq_config first" >&2
        return 1
    fi
    
    if ! check_rabbitmq_running; then
        echo "WARNING: RabbitMQ is not running" >&2
    fi
    
    if check_profile_exists; then
        if verify_profile_config; then
            return 0
        else
            echo "ERROR: Profile configuration mismatch" >&2
            return 1
        fi
    else
        create_aiida_profile
        if [[ $? -eq 0 ]]; then
            setup_aiida_user
            return $?
        else
            return 1
        fi
    fi
}

verify_aiida_profile() {
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    local profile_name="${CONFIG_VARS[PROFILE_NAME]}"
    
    if ! verdi profile list 2>/dev/null | grep -qE "^\*?\s*$profile_name\s*$"; then
        echo "ERROR: Profile '$profile_name' not found" >&2
        conda deactivate
        return 1
    fi
    
    local profile_info=$(verdi profile show "$profile_name" 2>/dev/null)
    if [[ -z "$profile_info" ]]; then
        echo "ERROR: Failed to retrieve profile information" >&2
        conda deactivate
        return 1
    fi
    
    if verdi -p "$profile_name" run execcode "print('Database connection OK')" 2>/dev/null; then
        return 0
    else
        echo "WARNING: Database connection test failed" >&2
    fi
    
    conda deactivate
    return 0
}

run_aiida_profile() {
    load_config
    export_config_vars
    
    configure_aiida_profile
    local config_status=$?
    
    if [[ $config_status -eq 0 ]]; then
        verify_aiida_profile
        return $?
    else
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_aiida_profile
fi
