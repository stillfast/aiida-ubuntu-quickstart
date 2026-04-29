#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

setup_profile() {
    report_header "Step 5/5: AiiDA Profile Setup"

    load_config

    local status=0
    local profile_exists=0
    local profile_is_default=0

    local profile_name="${PROFILE_NAME:-aiida_profile}"
    local user_email="${USER_EMAIL:-your.email@example.com}"
    local user_firstname="${USER_FIRSTNAME:-YourFirstName}"
    local user_lastname="${USER_LASTNAME:-YourLastName}"
    local user_institution="${USER_INSTITUTION:-YourInstitution}"

    local db_host="${DB_HOST:-127.0.0.1}"
    local db_port="${DB_PORT:-5432}"
    local db_user="${DB_USERNAME:-aiida_user}"
    local db_password="${DB_PASSWORD:-123}"
    local db_name="${DB_NAME:-aiida_db}"

    local repo_uri="${PROFILE_REPOSITORY_URI:-file:///tmp/aiida_repository}"

    echo "Checking existing profiles..."
    echo ""

    local existing_profiles
    existing_profiles=$(verdi profile list 2>/dev/null)

    if echo "$existing_profiles" | grep -q "$profile_name"; then
        profile_exists=1
        report_status "DONE" "Profile '$profile_name' already exists"

        if echo "$existing_profiles" | grep -E "^\*\s*$profile_name" > /dev/null; then
            profile_is_default=1
            report_item "Profile is already set as default"
        else
            report_status "WARN" "Profile exists but is not the default"
        fi

        echo ""
        echo "Profile details:"
        verdi profile show "$profile_name" 2>/dev/null | sed 's/^/  /'

        echo ""
        if [ $profile_is_default -eq 1 ]; then
            log_info "Profile '$profile_name' is already configured and set as default."
            log_info "No changes needed."
            echo ""

            echo "──────────────────────────────────────────"
            report_status "OK" "Profile exists"
            report_status "OK" "Profile is default"
            echo "──────────────────────────────────────────"
            echo ""
            log_success "Profile validation completed!"
            return 0
        else
            read -p "Set '$profile_name' as default profile? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                verdi profile setdefault "$profile_name"
                log_success "Set '$profile_name' as default profile"
                profile_is_default=1
            fi
        fi
    else
        report_status "SKIP" "Profile '$profile_name' does not exist"
        report_item "Will create new profile"
        echo ""
    fi

    if [ $profile_exists -eq 0 ]; then
        echo "Creating new AiiDA profile..."
        echo ""
        report_item "Profile name: $profile_name"
        report_item "Email: $user_email"
        report_item "User: $user_firstname $user_lastname"
        report_item "Institution: $user_institution"
        echo ""

        if verdi profile setup core.psql_dos -n \
            --profile-name "$profile_name" \
            --set-as-default \
            --email "$user_email" \
            --first-name "$user_firstname" \
            --last-name "$user_lastname" \
            --institution "$user_institution" \
            --use-rabbitmq \
            --database-username "$db_user" \
            --database-password "$db_password" \
            --database-name "$db_name" \
            --database-engine postgresql_psycopg \
            --database-hostname "$db_host" \
            --database-port "$db_port" \
            --repository-uri "$repo_uri"; then

            report_status "OK" "Profile created successfully"
            profile_exists=1
            profile_is_default=1
        else
            report_status "FAIL" "Failed to create profile"
            status=1
        fi
    fi

    echo ""
    if [ $profile_exists -eq 1 ]; then
        echo "Verifying profile..."
        verdi profile show "$profile_name" | sed 's/^/  /'
    fi

    echo ""
    echo "──────────────────────────────────────────"
    if [ $profile_exists -eq 1 ]; then
        report_status "OK" "Profile '$profile_name'"
    else
        report_status "FAIL" "Profile '$profile_name'"
    fi

    if [ $profile_is_default -eq 1 ]; then
        report_status "OK" "Profile is default"
    else
        report_status "WARN" "Profile is not default"
    fi
    echo "──────────────────────────────────────────"
    echo ""

    if [ $status -eq 0 ]; then
        log_success "Profile setup completed!"
    else
        log_error "Profile setup failed. Please check the errors above."
    fi

    return $status
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_profile
fi
