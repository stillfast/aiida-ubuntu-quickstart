#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01-env_loader.sh"

check_conda_installed() {
    if command -v conda &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_environment_exists() {
    local env_name="$1"
    if conda env list 2>/dev/null | grep -q "^$env_name "; then
        return 0
    else
        return 1
    fi
}

verify_conda_env_config() {
    local env_name="${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    echo "Verifying conda environment: $env_name"
    
    if ! check_environment_exists "$env_name"; then
        echo "Environment '$env_name' does not exist"
        return 1
    fi
    
    echo "Environment '$env_name' exists"
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$env_name"
    
    local configured_packages="${CONFIG_VARS[CONDA_PACKAGES]}"
    local missing_packages=()
    local version_mismatch=()
    
    for package in $configured_packages; do
        local pkg_name="${package%%=*}"
        if pip show "$pkg_name" &> /dev/null; then
            local installed_version=$(pip show "$pkg_name" 2>/dev/null | grep "^Version: " | awk '{print $2}')
            if [[ "$package" == *"="* ]]; then
                local required_version="${package##*=}"
                if [[ "$installed_version" != "$required_version" ]]; then
                    version_mismatch+=("$pkg_name (installed: $installed_version, required: $required_version)")
                fi
            fi
        else
            missing_packages+=("$pkg_name")
        fi
    done
    
    conda deactivate
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo "Missing packages: ${missing_packages[*]}"
        return 1
    fi
    
    if [[ ${#version_mismatch[@]} -gt 0 ]]; then
        echo "Version mismatches found:"
        printf '  - %s\n' "${version_mismatch[@]}"
        return 1
    fi
    
    echo "All packages are correctly installed"
    return 0
}

create_conda_env() {
    local env_name="${CONFIG_VARS[CONDA_ENV_NAME]}"
    local python_version="${CONFIG_VARS[CONDA_PYTHON_VERSION]}"
    local packages="${CONFIG_VARS[CONDA_PACKAGES]}"
    
    echo "Creating conda environment: $env_name"
    
    conda create -n "$env_name" python="$python_version" -y
    if [[ $? -ne 0 ]]; then
        echo "Failed to create conda environment" >&2
        return 1
    fi
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$env_name"
    
    echo "Installing packages via pip: $packages"
    pip install --upgrade pip setuptools wheel
    pip install $packages
    if [[ $? -ne 0 ]]; then
        echo "Failed to install packages via pip" >&2
        conda deactivate
        return 1
    fi
    
    conda deactivate
    
    echo "Conda environment '$env_name' created successfully"
    return 0
}

update_conda_packages() {
    local packages="${CONFIG_VARS[CONDA_PACKAGES]}"
    
    echo "Updating conda packages via pip..."
    
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONFIG_VARS[CONDA_ENV_NAME]}"
    
    pip install --upgrade pip setuptools wheel
    pip install --upgrade $packages
    local update_status=$?
    
    conda deactivate
    
    if [[ $update_status -ne 0 ]]; then
        echo "Failed to update packages" >&2
        return 1
    fi
    
    echo "Packages updated successfully"
    return 0
}

run_conda_manager() {
    echo "=== Conda Environment Management Module ==="
    
    load_config
    export_config_vars
    
    if ! check_conda_installed; then
        echo "ERROR: Conda is not installed" >&2
        return 1
    fi
    
    if check_environment_exists "${CONFIG_VARS[CONDA_ENV_NAME]}"; then
        if verify_conda_env_config; then
            return 0
        else
            update_conda_packages
            return $?
        fi
    else
        create_conda_env
        return $?
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_conda_manager
fi
