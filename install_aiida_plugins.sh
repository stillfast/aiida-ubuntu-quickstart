#!/bin/bash

# Configurable variables
QE_SOURCE_DIR="$HOME/install/aiida-quantumespresso"
QE_REPO="https://github.com/aiidateam/aiida-quantumespresso.git"
AIIDA_CORE_SOURCE_DIR="$HOME/install/aiida-core"
AIIDA_CORE_REPO="https://github.com/aiidateam/aiida-core.git"
VASP_SOURCE_DIR="$HOME/install/aiida-vasp"
VASP_REPO="https://github.com/aiida-vasp/aiida-vasp.git"
ABACUS_REPO="https://github.com/stillfast/aiida-abacus.git"
ABACUS_BRANCH="develop"
ABACUS_MERGE_BRANCH="feature/add-scf-opt-convergence-check"
ABACUS_DIR="$HOME/install/aiida-abacus"
GIT_TIMEOUT=60


log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

install_qe_plugin() {
    log "Installing aiida-quantumespresso plugin..."
    pip install PyCifRW

    mkdir -p "$HOME/install"

    if [ ! -d "$QE_SOURCE_DIR" ]; then
        log "Cloning aiida-quantumespresso from $QE_REPO..."
        timeout $GIT_TIMEOUT git clone "$QE_REPO" "$QE_SOURCE_DIR"
        if [ $? -ne 0 ]; then
            log "Git clone failed, trying tarball..."
            cd "$HOME/install" || return 1
            timeout $GIT_TIMEOUT wget -q https://github.com/aiidateam/aiida-quantumespresso/archive/refs/heads/main.tar.gz -O aiida-quantumespresso.tar.gz
            if [ $? -eq 0 ]; then
                tar -xzf aiida-quantumespresso.tar.gz
                if [ -d "aiida-quantumespresso-main" ]; then
                    mv aiida-quantumespresso-main "$QE_SOURCE_DIR"
                    rm -f aiida-quantumespresso.tar.gz
                    log "Tarball extraction completed"
                else
                    log "ERROR: Failed to extract tarball"
                    return 1
                fi
            else
                log "ERROR: Failed to download tarball"
                return 1
            fi
        else
            log "Git clone successful"
        fi
    else
        log "aiida-quantumespresso source already exists at $QE_SOURCE_DIR"
    fi

    if [ -d "$QE_SOURCE_DIR" ]; then
        log "Installing aiida-quantumespresso in editable mode..."
        pip install -e "$QE_SOURCE_DIR"

        QE_PATCH_TARGET="$QE_SOURCE_DIR/src/aiida_quantumespresso/workflows/pw/base.py"

        if [ -f "$QE_PATCH_TARGET" ]; then
            log "Patching $QE_PATCH_TARGET to remove ppcg from diagonalization fallback list..."
            sed -i "s/\['cg', 'paro', 'ppcg', 'david'\]/['david', 'paro', 'cg']/g" "$QE_PATCH_TARGET"
            log "Patch completed"
        else
            log "Warning: base.py not found at $QE_PATCH_TARGET"
        fi

        NEB_PATCH_TARGET="$QE_SOURCE_DIR/src/aiida_quantumespresso/workflows/neb/base.py"
        if [ -f "$NEB_PATCH_TARGET" ]; then
            log "Patching $NEB_PATCH_TARGET to remove ppcg from diagonalization fallback list..."
            sed -i "s/\['cg', 'paro', 'ppcg', 'david'\]/['david', 'paro', 'cg']/g" "$NEB_PATCH_TARGET"
            log "NEB patch completed"
        else
            log "Warning: neb/base.py not found at $NEB_PATCH_TARGET"
        fi
    else
        log "ERROR: QE_SOURCE_DIR not found after installation"
        return 1
    fi

    log "aiida-quantumespresso installation completed"
}

install_aiida_core() {
    log "Installing aiida-core from git..."

    mkdir -p "$HOME/install"

    if [ ! -d "$AIIDA_CORE_SOURCE_DIR" ]; then
        log "Cloning aiida-core from $AIIDA_CORE_REPO..."
        timeout $GIT_TIMEOUT git clone "$AIIDA_CORE_REPO" "$AIIDA_CORE_SOURCE_DIR"
        if [ $? -ne 0 ]; then
            log "Git clone failed, trying tarball..."
            cd "$HOME/install" || return 1
            timeout $GIT_TIMEOUT wget -q https://github.com/aiidateam/aiida-core/archive/refs/heads/main.tar.gz -O aiida-core.tar.gz
            if [ $? -eq 0 ]; then
                tar -xzf aiida-core.tar.gz
                if [ -d "aiida-core-main" ]; then
                    mv aiida-core-main "$AIIDA_CORE_SOURCE_DIR"
                    rm -f aiida-core.tar.gz
                    log "Tarball extraction completed"
                else
                    log "ERROR: Failed to extract tarball"
                    return 1
                fi
            else
                log "ERROR: Failed to download tarball"
                return 1
            fi
        else
            log "Git clone successful"
        fi
    else
        log "aiida-core source already exists at $AIIDA_CORE_SOURCE_DIR"
    fi

    if [ -d "$AIIDA_CORE_SOURCE_DIR" ]; then
        log "Installing aiida-core in editable mode..."
        pip install -e "$AIIDA_CORE_SOURCE_DIR"
    else
        log "ERROR: AIIDA_CORE_SOURCE_DIR not found after installation"
        return 1
    fi
}

patch_aiida_core() {
    log "Patching aiida-core..."

    ASYNC_BACKEND_FILE="$AIIDA_CORE_SOURCE_DIR/aiida/transports/plugins/async_backend.py"

    if [ ! -f "$ASYNC_BACKEND_FILE" ]; then
        log "Error: async_backend.py not found at $ASYNC_BACKEND_FILE"
        return 1
    fi

    log "Patching $ASYNC_BACKEND_FILE..."

    python3 << 'PYTHON_SCRIPT'
import os
import sys

file_path = sys.argv[1]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

modified = False

if "special = set(' \\t\\n\"\'`$\\!#&*?;<>|(){}')" in content:
    content = content.replace(
        "special = set(' \\t\\n\"\'`$\\!#&*?;<>|(){}')",
        "special = set(' \\t\\n\"\'`$\\!#&*?;<>|{}')"
    )
    print("Patched special characters")
    modified = True

if "return process.returncode, stdout.decode(), stderr.decode()" in content:
    old_code = "return process.returncode, stdout.decode(), stderr.decode()"
    new_code = """stderr_decoded = stderr.decode()
        filtered_stderr = []
        for line in stderr_decoded.split('\\n'):
            if 'warning: ' in line.lower():
                self.logger.debug('SSH warning filtered: %s', line)
            else:
                filtered_stderr.append(line)
        filtered_stderr = '\\n'.join(filtered_stderr)
        return process.returncode, stdout.decode(), filtered_stderr"""
    
    content = content.replace(old_code, new_code)
    print("Patched stderr filtering")
    modified = True

if modified:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("File updated successfully")
else:
    print("No changes needed or pattern not found")
PYTHON_SCRIPT
    "$ASYNC_BACKEND_FILE"

    log "aiida-core patching completed"
}

install_aiida_vasp() {
    log "Installing aiida-vasp plugin..."
    pip install ase

    log "Fixing ASE NEB import..."
    python3 << 'PYTHON_SCRIPT'
from pathlib import Path
import importlib

try:
    importlib.import_module('ase.neb')
    print("ase.neb already works")
except Exception:
    pass

ase = importlib.import_module('ase')
importlib.import_module('ase.mep.neb')
ase_dir = Path(ase.__file__).resolve().parent
(ase_dir / 'neb.py').write_text('from ase.mep.neb import *\n', encoding='utf-8')
importlib.invalidate_caches()
importlib.import_module('ase.neb')
print("ASE NEB import fixed")
PYTHON_SCRIPT

    mkdir -p "$HOME/install"

    if [ ! -d "$VASP_SOURCE_DIR" ]; then
        log "Cloning aiida-vasp from $VASP_REPO..."
        timeout $GIT_TIMEOUT git clone "$VASP_REPO" "$VASP_SOURCE_DIR"
        if [ $? -ne 0 ]; then
            log "Git clone failed, trying tarball..."
            cd "$HOME/install" || return 1
            timeout $GIT_TIMEOUT wget -q https://github.com/aiida-vasp/aiida-vasp/archive/refs/heads/main.tar.gz -O aiida-vasp.tar.gz
            if [ $? -eq 0 ]; then
                tar -xzf aiida-vasp.tar.gz
                if [ -d "aiida-vasp-main" ]; then
                    mv aiida-vasp-main "$VASP_SOURCE_DIR"
                    rm -f aiida-vasp.tar.gz
                    log "Tarball extraction completed"
                else
                    log "ERROR: Failed to extract tarball"
                    return 1
                fi
            else
                log "ERROR: Failed to download tarball"
                return 1
            fi
        else
            log "Git clone successful"
        fi
    else
        log "aiida-vasp source already exists at $VASP_SOURCE_DIR"
    fi

    if [ -d "$VASP_SOURCE_DIR" ]; then
        log "Installing aiida-vasp in editable mode..."
        pip install -e "$VASP_SOURCE_DIR"
    else
        log "ERROR: VASP_SOURCE_DIR not found after installation"
        return 1
    fi

    log "aiida-vasp installation completed"
}

install_aiida_abacus() {
    log "Installing aiida-abacus plugin..."
    
    mkdir -p "$HOME/install"
    
    if [ ! -d "$ABACUS_DIR" ]; then
        log "Cloning aiida-abacus from $ABACUS_REPO..."
        timeout $GIT_TIMEOUT git clone -b "$ABACUS_BRANCH" "$ABACUS_REPO" "$ABACUS_DIR" || {
            log "Git clone failed"
            return 1
        }
    else
        if [ ! -d "$ABACUS_DIR/.git" ]; then
            log "Directory exists but is not a git repo, removing and re-cloning..."
            rm -rf "$ABACUS_DIR"
            timeout $GIT_TIMEOUT git clone -b "$ABACUS_BRANCH" "$ABACUS_REPO" "$ABACUS_DIR" || {
                log "Git clone failed"
                return 1
            }
        else
            log "aiida-abacus source already exists at $ABACUS_DIR"
        fi
    fi
    
    cd "$ABACUS_DIR" || return 1
    
    log "Fetching origin branches..."
    git fetch origin
    
    log "Checking out $ABACUS_BRANCH branch..."
    git checkout "$ABACUS_BRANCH"
    
    log "Pulling latest $ABACUS_BRANCH..."
    git pull origin "$ABACUS_BRANCH"
    
    log "Merging $ABACUS_MERGE_BRANCH branch..."
    git merge "origin/$ABACUS_MERGE_BRANCH" || {
        log "Merge failed, removing conflict markers..."
        find . -name "*.py" -type f -exec sed -i 's/^<<<<<<< HEAD$//g' {} \;
        find . -name "*.py" -type f -exec sed -i 's/^=======$//g' {} \;
        find . -name "*.py" -type f -exec sed -i 's/^>>>>>>> origin\/.*$//g' {} \;
        git add -A
        git commit -m "Merge $ABACUS_MERGE_BRANCH into $ABACUS_BRANCH (conflict resolved)" || {
            log "Nothing to commit or merge already complete"
        }
    }
    
    log "Installing aiida-abacus in editable mode..."
    cd "$ABACUS_DIR"
    pip install -e .
    
    log "aiida-abacus installation completed"
}

# install_qe_plugin
install_aiida_core
patch_aiida_core
# install_aiida_vasp
install_aiida_abacus

