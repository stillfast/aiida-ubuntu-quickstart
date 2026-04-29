#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up script permissions..."
chmod +x "$SCRIPT_DIR/setup_aiida_profile.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null
echo "Permissions configured."

source "$SCRIPT_DIR/scripts/common.sh"

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║             AiiDA Profile Setup - Automated Script              ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    load_config
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

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Starting setup process..."
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    "$SCRIPT_DIR/scripts/00-setup-conda.sh" || overall_status=1
    "$SCRIPT_DIR/scripts/01-validate-postgresql.sh" || overall_status=1
    "$SCRIPT_DIR/scripts/02-validate-rabbitmq.sh" || log_warn "RabbitMQ validation had warnings (non-blocking)."
    "$SCRIPT_DIR/scripts/04-setup-profile.sh" || overall_status=1

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Setup Complete (${duration}s)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    if [ $overall_status -eq 0 ]; then
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║              ✓ Setup completed successfully!                    ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        log_info "Next steps:"
        echo "  1. Activate environment: conda activate ${CONDA_ENV_NAME:-aiida}"
        echo "  2. Test connection: verdi status"
    else
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║              ✗ Setup completed with errors                     ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        log_warn "Please review the errors above and fix them manually."
    fi
    echo ""

    return $overall_status
}

main "$@"
