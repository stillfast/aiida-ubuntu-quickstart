#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

validate_postgresql() {
    report_header "Step 1/5: PostgreSQL Validation"

    load_config

    local status=0
    local installed=0
    local running=0
    local connected=0

    local db_host="${DB_HOST:-127.0.0.1}"
    local db_port="${DB_PORT:-5432}"
    local db_user="${DB_USERNAME:-aiida_user}"
    local db_password="${DB_PASSWORD:-123}"
    local db_name="${DB_NAME:-aiida_db}"
    local db_data_dir="${DB_DATA_DIR:-$HOME/mylocal_db}"

    echo "Checking PostgreSQL installation..."
    echo ""

    if command -v psql &> /dev/null; then
        local psql_version
        psql_version=$(psql --version 2>/dev/null | awk '{print $3}')
        report_status "OK" "PostgreSQL client installed: $psql_version"
        installed=1
    else
        report_status "FAIL" "PostgreSQL client not found"
        report_item "Installing PostgreSQL..."
        if conda install -n base -c conda-forge postgresql -y &> /dev/null; then
            report_status "OK" "PostgreSQL installed successfully"
            installed=1
        else
            report_status "FAIL" "Failed to install PostgreSQL"
            return 1
        fi
    fi

    echo ""
    echo "Checking PostgreSQL server..."
    echo ""

    if [ $installed -eq 1 ]; then
        if command -v pg_isready &> /dev/null; then
            if pg_isready -h "$db_host" -p "$db_port" &> /dev/null; then
                report_status "OK" "PostgreSQL server is running on $db_host:$db_port"
                running=1
            else
                report_status "WARN" "PostgreSQL server not responding on $db_host:$db_port"
                report_item "Starting PostgreSQL server..."

                if [ ! -d "$db_data_dir" ]; then
                    report_item "Creating database directory: $db_data_dir"
                    mkdir -p "$db_data_dir"
                fi

                if [ ! -f "$db_data_dir/postgresql.conf" ]; then
                    report_item "Initializing database cluster..."
                    initdb -D "$db_data_dir" &> /dev/null
                    if [ $? -ne 0 ]; then
                        report_status "FAIL" "Failed to initialize database cluster"
                        return 1
                    fi
                fi

                report_item "Starting PostgreSQL with: pg_ctl -D $db_data_dir -o '-p $db_port' -l $db_data_dir/logfile start"
                pg_ctl -D "$db_data_dir" -o "-p $db_port" -l "$db_data_dir/logfile" start &> /dev/null

                sleep 3

                if pg_isready -h "$db_host" -p "$db_port" &> /dev/null; then
                    report_status "OK" "PostgreSQL server started successfully"
                    running=1
                else
                    report_status "FAIL" "Failed to start PostgreSQL server"
                    report_item "Check logs at: $db_data_dir/logfile"
                    return 1
                fi
            fi
        else
            report_status "WARN" "pg_isready not found"
            running=1
        fi
    fi

    echo ""
    echo "Testing database connection..."
    echo ""

    if [ $installed -eq 1 ] && [ $running -eq 1 ]; then
        export PGPASSWORD="$db_password"

        if PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -c "SELECT 1;" &> /dev/null; then
            report_status "OK" "Connected to PostgreSQL server"

            local user_exists=$(PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -t -c "SELECT 1 FROM pg_roles WHERE rolname='$db_user';" 2>/dev/null | xargs)

            if [ "$user_exists" != "1" ]; then
                report_item "Creating user '$db_user'..."
                PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -c "CREATE USER $db_user WITH PASSWORD '$db_password';" &> /dev/null
                PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -c "ALTER USER $db_user CREATEDB;" &> /dev/null
                report_status "OK" "User '$db_user' created"
            else
                report_status "OK" "User '$db_user' already exists"
            fi

            local db_exists_check=$(PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -w "$db_name" | xargs)

            if [ "$db_exists_check" != "$db_name" ]; then
                report_item "Creating database '$db_name'..."
                PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -c "CREATE DATABASE $db_name OWNER $db_user;" &> /dev/null
                PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;" &> /dev/null
                report_status "OK" "Database '$db_name' created"
            else
                report_status "OK" "Database '$db_name' already exists"
            fi

            if PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "SELECT 1;" &> /dev/null; then
                report_status "OK" "Connected to database '$db_name' as user '$db_user'"
                connected=1

                local db_version
                db_version=$(PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c "SELECT version();" 2>/dev/null | xargs)
                report_item "Database version: $db_version"
            else
                report_status "FAIL" "Cannot connect to database '$db_name' as user '$db_user'"
                status=1
            fi
        else
            report_status "FAIL" "Cannot connect to PostgreSQL as postgres user"
            status=1
        fi

        unset PGPASSWORD
    fi

    echo ""
    echo "──────────────────────────────────────────"
    echo "Summary:"
    if [ $installed -eq 1 ]; then
        report_status "OK" "PostgreSQL client"
    else
        report_status "FAIL" "PostgreSQL client"
    fi

    if [ $running -eq 1 ]; then
        report_status "OK" "PostgreSQL server"
    else
        report_status "FAIL" "PostgreSQL server"
    fi

    if [ $connected -eq 1 ]; then
        report_status "OK" "Database connection"
    else
        report_status "FAIL" "Database connection"
    fi
    echo "──────────────────────────────────────────"
    echo ""

    if [ $status -eq 0 ]; then
        log_success "PostgreSQL validation passed!"
    else
        log_error "PostgreSQL validation failed. Please fix the issues above."
    fi

    return $status
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_postgresql
fi
