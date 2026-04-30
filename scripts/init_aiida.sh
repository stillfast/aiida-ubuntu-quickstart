#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

AiiDA Project Initialization Script

OPTIONS:
    -a, --all           Run all modules (default if no option specified)
    -e, --env           Run environment variable management module
    -c, --conda         Run conda environment management module
    -d, --db            Run database and message queue configuration module
    -p, --profile       Run AiiDA profile configuration module
    -v, --validate      Validate configuration without executing
    -h, --help          Show this help message
    --dry-run           Show what would be executed without running

EXAMPLES:
    $(basename "$0")                    Run all modules
    $(basename "$0") -e                  Run only environment loader
    $(basename "$0") -c -d               Run conda and database modules
    $(basename "$0") --all --dry-run    Show what would be run

EOF
}

print_header() {
    echo "========================================="
    echo "  AiiDA Project Initialization"
    echo "========================================="
    echo ""
}

run_env_loader() {
    if ! "${SCRIPT_DIR}/01-env_loader.sh" 2>&1 | grep -q "ERROR"; then
        echo "✓ [1/4] Environment loader"
        return 0
    fi
    echo "ERROR: Environment loader failed" >&2
    return 1
}

run_conda_manager() {
    if ! "${SCRIPT_DIR}/02-conda_manager.sh" 2>&1 | grep -q "ERROR"; then
        echo "✓ [2/4] Conda environment"
        return 0
    fi
    echo "ERROR: Conda manager failed" >&2
    return 1
}

run_db_mq_config() {
    if ! "${SCRIPT_DIR}/03-db_mq_config.sh" 2>&1 | grep -q "ERROR"; then
        echo "✓ [3/4] Database & RabbitMQ"
        return 0
    fi
    echo "ERROR: Database/MQ configuration failed" >&2
    return 1
}

run_aiida_profile() {
    if ! "${SCRIPT_DIR}/04-aiida_profile.sh" 2>&1 | grep -q "ERROR"; then
        echo "✓ [4/4] AiiDA profile"
        return 0
    fi
    echo "ERROR: AiiDA profile configuration failed" >&2
    return 1
}

validate_config() {
    echo ">>> Validating Configuration"
    echo ""
    if ! "${SCRIPT_DIR}/01-env_loader.sh"; then
        echo "ERROR: Configuration validation failed" >&2
        return 1
    fi
    echo ""
    echo "✓ Configuration is valid"
    echo ""
    return 0
}

show_dry_run() {
    echo "The following modules would be executed:"
    echo ""
    echo "  1. Environment Variable Management (01-env_loader.sh)"
    echo "  2. Conda Environment Management (02-conda_manager.sh)"
    echo "  3. Database and Message Queue Configuration (03-db_mq_config.sh)"
    echo "  4. AiiDA Profile Configuration (04-aiida_profile.sh)"
    echo ""
    echo "Configuration file: ${SCRIPT_DIR}/../config.env"
    echo ""
}

run_all_modules() {
    print_header
    
    local failed=0
    
    run_env_loader || failed=1
    run_conda_manager || failed=1
    run_db_mq_config || failed=1
    run_aiida_profile || failed=1
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✓ All modules completed successfully!"
        return 0
    else
        echo "✗ Some modules failed" >&2
        return 1
    fi
}

main() {
    local modules=()
    local run_all=false
    local validate_only=false
    local dry_run=false
    
    if [[ $# -eq 0 ]]; then
        run_all=true
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                run_all=true
                shift
                ;;
            -e|--env)
                modules+=("env")
                shift
                ;;
            -c|--conda)
                modules+=("conda")
                shift
                ;;
            -d|--db)
                modules+=("db")
                shift
                ;;
            -p|--profile)
                modules+=("profile")
                shift
                ;;
            -v|--validate)
                validate_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
        esac
    done
    
    if [[ "$dry_run" == true ]]; then
        show_dry_run
        exit 0
    fi
    
    if [[ "$validate_only" == true ]]; then
        validate_config
        exit $?
    fi
    
    if [[ "$run_all" == true ]]; then
        run_all_modules
        exit $?
    fi
    
    print_header
    
    local failed=0
    for module in "${modules[@]}"; do
        case "$module" in
            env)
                run_env_loader || failed=1
                ;;
            conda)
                run_conda_manager || failed=1
                ;;
            db)
                run_db_mq_config || failed=1
                ;;
            profile)
                run_aiida_profile || failed=1
                ;;
        esac
    done
    
    exit $failed
}

main "$@"
