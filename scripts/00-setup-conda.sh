#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

setup_conda_env() {
    report_header "Step 0/5: Conda Environment Setup"

    load_config

    local status=0
    local env_exists=0

    echo "Checking conda installation..."
    echo ""

    if ! command -v conda &> /dev/null; then
        report_status "FAIL" "Conda is not installed or not in PATH"
        echo ""
        log_error "Please install Miniconda or Anaconda first."
        log_info "Download from: https://docs.conda.io/en/latest/miniconda.html"
        return 1
    fi

    local conda_version
    conda_version=$(conda --version 2>/dev/null | awk '{print $2}')
    report_status "OK" "Conda installed: $conda_version"

    echo ""
    echo "Checking conda environment: ${CONDA_ENV_NAME:-aiida}..."
    echo ""

    if conda env list 2>/dev/null | grep -q "^${CONDA_ENV_NAME:-aiida} "; then
        env_exists=1
        report_status "DONE" "Environment '${CONDA_ENV_NAME:-aiida}' already exists"

        echo ""
        read -p "Recreate environment? This will remove existing environment. (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing environment..."
            conda env remove -n "${CONDA_ENV_NAME:-aiida}" -y
            env_exists=0
        fi
    else
        report_status "SKIP" "Environment '${CONDA_ENV_NAME:-aiida}' does not exist"
    fi

    if [ $env_exists -eq 0 ]; then
        echo ""
        log_info "Creating conda environment..."
        echo ""

        local create_cmd
        create_cmd=$(get_conda_create_cmd)
        report_item "Command: $create_cmd"
        echo ""

        if conda create -n "${CONDA_ENV_NAME:-aiida}" python="${CONDA_PYTHON_VERSION:-3.10}" -y 2>&1 | tee /tmp/conda_create.log; then
            report_status "OK" "Environment created successfully"
        else
            report_status "FAIL" "Failed to create environment"
            log_error "Check log: /tmp/conda_create.log"
            status=1
        fi

        echo ""
        log_info "Installing packages..."

        local channels="${CONDA_CHANNELS:-conda-forge}"
        local packages="${CONDA_PACKAGES:-aiida-core aiida-vasp}"

        if [ -n "$packages" ]; then
            if conda install -n "${CONDA_ENV_NAME:-aiida}" -c "$channels" -y $packages 2>&1 | tee /tmp/conda_packages.log; then
                report_status "OK" "Packages installed successfully"
            else
                report_status "WARN" "Some packages failed to install"
                log_warn "Check log: /tmp/conda_packages.log"
            fi
        fi
    fi

    echo ""
    echo "──────────────────────────────────────────"
    echo "Summary:"
    if [ $env_exists -eq 1 ]; then
        report_status "OK" "Environment '${CONDA_ENV_NAME:-aiida}' ready"
    else
        report_status "OK" "Environment '${CONDA_ENV_NAME:-aiida}' created"
    fi
    echo "──────────────────────────────────────────"
    echo ""

    echo "Usage:"
    echo "  conda activate ${CONDA_ENV_NAME:-aiida}"
    echo ""

    if [ $status -eq 0 ]; then
        log_success "Conda environment setup completed!"
    else
        log_error "Conda environment setup failed."
    fi

    return $status
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_conda_env
fi
