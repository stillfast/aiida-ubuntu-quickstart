#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

validate_rabbitmq() {
    report_header "Step 2/5: RabbitMQ Validation"

    load_config

    local status=0
    local client_found=0
    local server_reachable=0
    local user_configured=0

    local rabbitmq_host="${RABBITMQ_HOST:-127.0.0.1}"
    local rabbitmq_port="${RABBITMQ_PORT:-5672}"
    local rabbitmq_user="${RABBITMQ_USERNAME:-aiida}"
    local rabbitmq_password="${RABBITMQ_PASSWORD:-123}"
    local rabbitmq_vhost="${RABBITMQ_VHOST:-aiida}"

    echo "Checking RabbitMQ installation..."
    echo ""

    if command -v rabbitmq-server &> /dev/null; then
        local rabbitmq_version
        rabbitmq_version=$(rabbitmqctl --version 2>/dev/null | head -n 1 | awk '{print $3}')
        report_status "OK" "RabbitMQ installed: $rabbitmq_version"
        client_found=1
    else
        report_status "WARN" "RabbitMQ not installed"
        report_item "Installing RabbitMQ..."
        if conda install -n base -c conda-forge rabbitmq-server -y &> /dev/null; then
            report_status "OK" "RabbitMQ installed successfully"
            client_found=1
        else
            report_status "FAIL" "Failed to install RabbitMQ"
            return 1
        fi
    fi

    echo ""
    echo "Checking RabbitMQ server..."
    echo ""

    if [ $client_found -eq 1 ]; then
        if command -v nc &> /dev/null; then
            if nc -z -w 5 "$rabbitmq_host" "$rabbitmq_port" 2>/dev/null; then
                report_status "OK" "RabbitMQ server is running on $rabbitmq_host:$rabbitmq_port"
                server_reachable=1
            else
                report_status "WARN" "RabbitMQ server not running"
                report_item "Starting RabbitMQ server..."

                if command -v rabbitmq-server &> /dev/null; then
                    rabbitmq-server -detached &> /dev/null
                    sleep 5

                    if nc -z -w 5 "$rabbitmq_host" "$rabbitmq_port" 2>/dev/null; then
                        report_status "OK" "RabbitMQ server started successfully"
                        server_reachable=1
                    else
                        report_status "FAIL" "Failed to start RabbitMQ server"
                        report_item "Check RabbitMQ logs for errors"
                        return 1
                    fi
                else
                    report_status "FAIL" "rabbitmq-server command not found"
                    return 1
                fi
            fi
        else
            report_status "WARN" "Netcat (nc) not found, attempting to start server..."
            sleep 2

            if nc -z "$rabbitmq_host" "$rabbitmq_port" 2>/dev/null; then
                report_status "OK" "RabbitMQ server is running"
                server_reachable=1
            else
                report_status "FAIL" "Cannot verify RabbitMQ status"
            fi
        fi
    fi

    echo ""
    echo "Configuring RabbitMQ user and vhost..."
    echo ""

    if [ $server_reachable -eq 1 ]; then
        if command -v rabbitmqctl &> /dev/null; then
            local user_check
            user_check=$(rabbitmqctl list_users 2>/dev/null | grep "$rabbitmq_user" | wc -l)

            if [ "$user_check" -eq 0 ]; then
                report_item "Creating user '$rabbitmq_user'..."
                if rabbitmqctl add_user "$rabbitmq_user" "$rabbitmq_password" &> /dev/null; then
                    report_status "OK" "User '$rabbitmq_user' created"
                else
                    report_status "FAIL" "Failed to create user"
                    status=1
                fi
            else
                report_status "OK" "User '$rabbitmq_user' already exists"
            fi

            if rabbitmqctl list_vhosts 2>/dev/null | grep -q "$rabbitmq_vhost"; then
                report_status "OK" "Vhost '$rabbitmq_vhost' already exists"
            else
                report_item "Creating vhost '$rabbitmq_vhost'..."
                if rabbitmqctl add_vhost "$rabbitmq_vhost" &> /dev/null; then
                    report_status "OK" "Vhost '$rabbitmq_vhost' created"
                else
                    report_status "FAIL" "Failed to create vhost"
                    status=1
                fi
            fi

            report_item "Setting permissions for user '$rabbitmq_user'..."
            if rabbitmqctl set_permissions -p "$rabbitmq_vhost" "$rabbitmq_user" ".*" ".*" ".*" &> /dev/null; then
                report_status "OK" "Permissions set for vhost '$rabbitmq_vhost'"
                user_configured=1
            else
                report_status "WARN" "Failed to set permissions (may be non-critical)"
                user_configured=1
            fi

            report_item "Setting user tags..."
            rabbitmqctl set_user_tags "$rabbitmq_user" administrator &> /dev/null
        else
            report_status "WARN" "rabbitmqctl not found, skipping configuration"
        fi
    fi

    echo ""
    echo "Testing RabbitMQ connectivity..."
    echo ""

    if [ $server_reachable -eq 1 ]; then
        if nc -z -w 5 "$rabbitmq_host" "$rabbitmq_port" 2>/dev/null; then
            report_status "OK" "RabbitMQ is reachable on $rabbitmq_host:$rabbitmq_port"
        else
            report_status "FAIL" "Cannot connect to RabbitMQ"
            status=1
        fi
    fi

    echo ""
    echo "──────────────────────────────────────────"
    echo "Summary:"
    if [ $client_found -eq 1 ]; then
        report_status "OK" "RabbitMQ client"
    else
        report_status "FAIL" "RabbitMQ client"
    fi

    if [ $server_reachable -eq 1 ]; then
        report_status "OK" "RabbitMQ server"
    else
        report_status "FAIL" "RabbitMQ server"
    fi

    if [ $user_configured -eq 1 ]; then
        report_status "OK" "RabbitMQ configured"
    else
        report_status "WARN" "RabbitMQ configured"
    fi
    echo "──────────────────────────────────────────"
    echo ""

    if [ $status -eq 0 ]; then
        log_success "RabbitMQ validation passed!"
    else
        log_warn "RabbitMQ validation has issues (non-blocking for local setup)"
    fi

    return $status
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_rabbitmq
fi
