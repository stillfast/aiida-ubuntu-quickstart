#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

validate_aiida() {
    report_header "Step 3/5: AiiDA Installation Validation"

    load_config

    local status=0
    local verdi_found=0
    local verdi_working=0

    echo "Checking AiiDA installation..."
    echo ""

    if command -v verdi &> /dev/null; then
        verdi_found=1
        report_status "OK" "AiiDA verdi command found"

        local verdi_version
        verdi_version=$(verdi version 2>/dev/null || echo "unknown")
        report_item "AiiDA version: $verdi_version"
    else
        report_status "FAIL" "AiiDA not found in PATH"
        report_item "Install AiiDA with:"
        report_item "  conda create -n ${CONDA_ENV_NAME:-aiida} python=${CONDA_PYTHON_VERSION:-3.10} -c ${CONDA_CHANNELS:-conda-forge} aiida-core"
        report_item "  conda activate ${CONDA_ENV_NAME:-aiida}"
        status=1
    fi

    echo ""
    echo "Checking AiiDA configuration..."
    echo ""

    if [ $verdi_found -eq 1 ]; then
        if verdi profile list &> /dev/null; then
            verdi_working=1
            report_status "OK" "AiiDA verdi is working"

            echo ""
            report_item "Existing profiles:"
            verdi profile list 2>/dev/null | sed 's/^/    /'

            local default_profile
            default_profile=$(verdi profile list 2>/dev/null | grep -o "\*" | head -1)
            if [ -n "$default_profile" ]; then
                report_item "Default profile is set"
            else
                report_status "WARN" "No default profile configured"
            fi
        else
            report_status "FAIL" "AiiDA verdi is not properly configured"
            report_item "Try running: verdi setup"
            status=1
        fi
    fi

    echo ""
    echo "──────────────────────────────────────────"
    echo "Summary:"
    if [ $verdi_found -eq 1 ]; then
        report_status "OK" "AiiDA verdi command"
    else
        report_status "FAIL" "AiiDA verdi command"
    fi

    if [ $verdi_working -eq 1 ]; then
        report_status "OK" "AiiDA configuration"
    else
        report_status "FAIL" "AiiDA configuration"
    fi
    echo "──────────────────────────────────────────"
    echo ""

    if [ $status -eq 0 ]; then
        log_success "AiiDA validation passed!"
    else
        log_error "AiiDA validation failed. Please install and configure AiiDA first."
    fi

    return $status
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_aiida
fi
