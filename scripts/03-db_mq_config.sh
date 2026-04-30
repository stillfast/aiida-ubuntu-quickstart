#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01-env_loader.sh"

check_postgres_installed() {
    if command -v psql &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_postgres_running() {
    local host="${CONFIG_VARS[DB_HOST]}"
    local port="${CONFIG_VARS[DB_PORT]}"
    local db_path="${CONFIG_VARS[DB_PATH]}"
    local runtime_dir="${db_path}/runtime"
    
    if [[ -d "$runtime_dir" ]] && pg_isready -h "$runtime_dir" -p "$port" &> /dev/null; then
        return 0
    elif pg_isready -h "$host" -p "$port" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_postgres_user_exists() {
    local username="${CONFIG_VARS[DB_USERNAME]}"
    local port="${CONFIG_VARS[DB_PORT]}"
    local db_path="${CONFIG_VARS[DB_PATH]}"
    local runtime_dir="${db_path}/runtime"
    
    local superuser=$(whoami)
    local pghost="$runtime_dir"
    
    if psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$username'" 2>/dev/null | grep -q 1; then
        return 0
    else
        return 1
    fi
}

check_postgres_database_exists() {
    local dbname="${CONFIG_VARS[DB_NAME]}"
    local port="${CONFIG_VARS[DB_PORT]}"
    local db_path="${CONFIG_VARS[DB_PATH]}"
    local runtime_dir="${db_path}/runtime"
    
    local superuser=$(whoami)
    local pghost="$runtime_dir"
    
    if psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$dbname'" 2>/dev/null | grep -q 1; then
        return 0
    else
        return 1
    fi
}

create_postgres_user() {
    local username="${CONFIG_VARS[DB_USERNAME]}"
    local password="${CONFIG_VARS[DB_PASSWORD]}"
    local port="${CONFIG_VARS[DB_PORT]}"
    local db_path="${CONFIG_VARS[DB_PATH]}"
    local runtime_dir="${db_path}/runtime"
    
    echo "Creating PostgreSQL user: $username"
    
    local superuser=$(whoami)
    local pghost="$runtime_dir"
    
    export PGPASSWORD="$password"
    psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -c "CREATE USER $username WITH PASSWORD '$password';" 2>&1 | grep -v "already exists" || true
    psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -c "ALTER USER $username CREATEDB;" 2>&1 | grep -v "already exists" || true
    unset PGPASSWORD
    
    if psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$username'" 2>/dev/null | grep -q 1; then
        echo "PostgreSQL user '$username' created successfully"
        return 0
    else
        echo "ERROR: Failed to create user '$username'" >&2
        return 1
    fi
}

create_postgres_database() {
    local dbname="${CONFIG_VARS[DB_NAME]}"
    local username="${CONFIG_VARS[DB_USERNAME]}"
    local port="${CONFIG_VARS[DB_PORT]}"
    local db_path="${CONFIG_VARS[DB_PATH]}"
    local runtime_dir="${db_path}/runtime"
    
    echo "Creating PostgreSQL database: $dbname"
    
    local superuser=$(whoami)
    local pghost="$runtime_dir"
    
    psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -c "CREATE DATABASE $dbname OWNER $username;" 2>&1 | grep -v "already exists" || true
    psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -c "ALTER DATABASE $dbname SET timezone TO 'Asia/Shanghai';" 2>&1 | grep -v "already exists" || true
    
    if psql -h "$pghost" -p "$port" -U "$superuser" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$dbname'" 2>/dev/null | grep -q 1; then
        echo "PostgreSQL database '$dbname' created successfully"
        return 0
    else
        echo "ERROR: Failed to create database '$dbname'" >&2
        return 1
    fi
}

start_postgres_service() {
    echo "Starting PostgreSQL service..."
    
    local port="${CONFIG_VARS[DB_PORT]}"
    local db_data_dir="${CONFIG_VARS[DB_PATH]}"
    local db_runtime_dir="${db_data_dir}/runtime"
    
    if [[ ! -w "$(dirname "$db_data_dir")" ]]; then
        echo "WARNING: Configured path $db_data_dir is not writable" >&2
        db_data_dir="/tmp/aiida_postgres_data"
        db_runtime_dir="${db_data_dir}/runtime"
        echo "Using fallback path: $db_data_dir" >&2
    fi
    
    local db_data_parent="$(dirname "$db_data_dir")"
    if [[ ! -d "$db_data_parent" ]]; then
        echo "Creating database parent directory: $db_data_parent"
        mkdir -p "$db_data_parent"
        if [[ $? -ne 0 ]]; then
            echo "ERROR: Failed to create directory $db_data_parent" >&2
            echo "Please ensure the parent directory exists and is writable" >&2
            return 1
        fi
    fi
    
    if [[ ! -d "$db_data_dir" ]]; then
        echo "Creating PostgreSQL data directory: $db_data_dir"
        mkdir -p "$db_data_dir"
    fi
    
    if [[ ! -f "$db_data_dir/PG_VERSION" ]]; then
        echo "Initializing PostgreSQL database..."
        initdb -D "$db_data_dir"
        if [[ $? -ne 0 ]]; then
            echo "Failed to initialize PostgreSQL database" >&2
            return 1
        fi
    fi
    
    if [[ ! -d "$db_runtime_dir" ]]; then
        echo "Creating runtime directory: $db_runtime_dir"
        mkdir -p "$db_runtime_dir"
    fi
    
    echo "Configuring PostgreSQL..."
    sed -i "s|^#unix_socket_directories = .*|unix_socket_directories = '$db_runtime_dir'|" "$db_data_dir/postgresql.conf"
    sed -i "s|^unix_socket_directories = .*|unix_socket_directories = '$db_runtime_dir'|" "$db_data_dir/postgresql.conf"
    
    sed -i "s|^#listen_addresses = .*|listen_addresses = 'localhost'|" "$db_data_dir/postgresql.conf"
    sed -i "s|^listen_addresses = .*|listen_addresses = 'localhost'|" "$db_data_dir/postgresql.conf"
    
    if ! grep -q "^host.*all.*all.*127.0.0.1.*md5" "$db_data_dir/pg_hba.conf" 2>/dev/null; then
        echo "host all all 127.0.0.1/32 md5" >> "$db_data_dir/pg_hba.conf"
    fi
    
    echo "Starting PostgreSQL on port $port with custom runtime dir..."
    export PGHOST="$db_runtime_dir"
    export PGPORT="$port"
    pg_ctl -D "$db_data_dir" -l "$db_data_dir/logfile" start
    local start_status=$?
    unset PGHOST
    unset PGPORT
    
    sleep 3
    
    if check_postgres_running; then
        echo "PostgreSQL service started successfully"
        echo "Database directory: $db_data_dir"
        echo "Runtime directory: $db_runtime_dir"
        return 0
    else
        echo "Failed to start PostgreSQL service" >&2
        if [[ -f "$db_data_dir/logfile" ]]; then
            echo "PostgreSQL log:" >&2
            tail -30 "$db_data_dir/logfile" >&2
        fi
        return 1
    fi
}

verify_postgres_config() {
    echo "Verifying PostgreSQL configuration..."
    
    if ! check_postgres_running; then
        echo "PostgreSQL is not running"
        return 1
    fi
    
    local user_exists=false
    local db_exists=false
    
    if check_postgres_user_exists; then
        echo "User '${CONFIG_VARS[DB_USERNAME]}' exists"
        user_exists=true
    else
        echo "User '${CONFIG_VARS[DB_USERNAME]}' does not exist"
    fi
    
    if check_postgres_database_exists; then
        echo "Database '${CONFIG_VARS[DB_NAME]}' exists"
        db_exists=true
    else
        echo "Database '${CONFIG_VARS[DB_NAME]}' does not exist"
    fi
    
    if ! $user_exists || ! $db_exists; then
        return 1
    fi
    
    echo "PostgreSQL configuration is correct"
    return 0
}

setup_postgres() {
    local port="${CONFIG_VARS[DB_PORT]}"
    
    if ! check_postgres_installed; then
        echo "Installing PostgreSQL via conda..."
        source "$(conda info --base)/etc/profile.d/conda.sh"
        conda install -c conda-forge postgresql -y
        if [[ $? -ne 0 ]]; then
            echo "Failed to install PostgreSQL via conda" >&2
            echo "Please install PostgreSQL manually or via system package manager" >&2
            return 1
        fi
    fi
    
    if ! check_postgres_running; then
        start_postgres_service || return 1
    fi
    
    if ! verify_postgres_config; then
        if ! check_postgres_user_exists; then
            create_postgres_user || return 1
        fi
        
        if ! check_postgres_database_exists; then
            create_postgres_database || return 1
        fi
    fi
    
    echo "PostgreSQL setup completed successfully on port $port"
    return 0
}

check_rabbitmq_installed() {
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]] && [[ "${CONDA_DEFAULT_ENV}" == "${CONFIG_VARS[CONDA_ENV_NAME]}" ]]; then
        command -v rabbitmq-server &> /dev/null || command -v rabbitmqctl &> /dev/null
    else
        local conda_sh="$(conda info --base)/etc/profile.d/conda.sh"
        if [[ -f "$conda_sh" ]]; then
            source "$conda_sh"
            conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}" 2>/dev/null || true
            command -v rabbitmq-server &> /dev/null || command -v rabbitmqctl &> /dev/null
        else
            return 1
        fi
    fi
}

check_rabbitmq_running() {
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]] && [[ "${CONDA_DEFAULT_ENV}" == "${CONFIG_VARS[CONDA_ENV_NAME]}" ]]; then
        if command -v rabbitmqctl &> /dev/null; then
            rabbitmqctl status 2>&1 | grep -q "rabbit.*running"
        else
            return 1
        fi
    else
        local conda_sh="$(conda info --base)/etc/profile.d/conda.sh"
        if [[ -f "$conda_sh" ]]; then
            source "$conda_sh"
            conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}" 2>/dev/null || true
            if command -v rabbitmqctl &> /dev/null; then
                rabbitmqctl status 2>&1 | grep -q "rabbit.*running"
            else
                conda deactivate 2>/dev/null || true
                return 1
            fi
        else
            return 1
        fi
    fi
}

setup_rabbitmq() {
    local rabbitmq_version="${CONFIG_VARS[RABBITMQ_VERSION]}"
    local env_name="${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    if check_rabbitmq_installed; then
        echo "RabbitMQ is already installed"
        return 0
    fi
    
    echo "Installing RabbitMQ $rabbitmq_version via conda..."
    
    local conda_sh="$(conda info --base)/etc/profile.d/conda.sh"
    if [[ ! -f "$conda_sh" ]]; then
        echo "ERROR: Conda initialization script not found at $conda_sh" >&2
        return 1
    fi
    
    source "$conda_sh"
    
    if ! conda env list 2>/dev/null | grep -q "^$env_name "; then
        echo "ERROR: Conda environment '$env_name' does not exist" >&2
        return 1
    fi
    
    conda install -n "$env_name" -c conda-forge::rabbitmq-server="$rabbitmq_version" -y
    local install_status=$?
    
    if [[ $install_status -ne 0 ]]; then
        echo "WARNING: Failed to install specific version $rabbitmq_version, trying without version constraint..." >&2
        conda install -n "$env_name" -c conda-forge rabbitmq-server -y
        install_status=$?
        
        if [[ $install_status -ne 0 ]]; then
            echo "ERROR: Failed to install RabbitMQ via conda" >&2
            echo "Please try installing manually: conda install -n $env_name -c conda-forge rabbitmq-server" >&2
            return 1
        fi
    fi
    
    sleep 2
    
    if ! check_rabbitmq_installed; then
        echo "ERROR: RabbitMQ installation completed but command not found in PATH" >&2
        return 1
    fi
    
    echo "RabbitMQ setup completed successfully"
    return 0
}

run_db_mq_config() {
    echo "=== Database and Message Queue Configuration Module ==="
    
    load_config
    export_config_vars
    
    setup_postgres
    local pg_status=$?
    
    setup_rabbitmq
    local mq_status=$?
    
    if [[ $pg_status -eq 0 ]] && [[ $mq_status -eq 0 ]]; then
        return 0
    else
        echo "ERROR: Database/MQ configuration failed" >&2
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_db_mq_config
fi
