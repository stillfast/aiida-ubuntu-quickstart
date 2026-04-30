#!/bin/bash

echo "========================================="
echo "  AiiDA Setup Diagnostics Tool"
echo "========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">>> Loading configuration..."
source "$SCRIPT_DIR/01-env_loader.sh"
load_config
export_config_vars

echo "✓ Configuration loaded"
echo ""

echo ">>> Checking critical paths..."
echo ""

echo "1. Database Path: ${DB_PATH:-N/A}"
if [[ -z "${DB_PATH:-}" ]]; then
    echo "   ❌ ERROR: DB_PATH not configured"
else
    db_parent="$(dirname "$DB_PATH")"
    if [[ ! -d "$db_parent" ]]; then
        echo "   ❌ ERROR: Parent directory does not exist: $db_parent"
    elif [[ ! -w "$db_parent" ]]; then
        echo "   ❌ ERROR: Parent directory is not writable: $db_parent"
        echo "   💡 Suggestion: Either:"
        echo "      - Make directory writable: chmod 755 $db_parent"
        echo "      - Or run: bash setup_aiida_profile.sh"
        echo "        (Script will use fallback /tmp directory automatically)"
    else
        echo "   ✅ OK: Directory is writable"
    fi
fi
echo ""

echo "2. Profile Repository: ${PROFILE_REPOSITORY_URI:-N/A}"
if [[ -z "${PROFILE_REPOSITORY_URI:-}" ]]; then
    echo "   ❌ ERROR: PROFILE_REPOSITORY_URI not configured"
else
    echo "   ✅ OK: Repository URI configured"
fi
echo ""

echo "3. Conda Environment: ${CONDA_ENV_NAME:-N/A}"
if [[ -z "${CONDA_ENV_NAME:-}" ]]; then
    echo "   ❌ ERROR: CONDA_ENV_NAME not configured"
else
    if command -v conda &> /dev/null; then
        if conda env list 2>/dev/null | grep -q "^${CONDA_ENV_NAME} "; then
            echo "   ✅ OK: Environment exists"
            source "$(conda info --base)/etc/profile.d/conda.sh"
            conda activate "${CONDA_ENV_NAME}"
            if command -v verdi &> /dev/null; then
                echo "   ✅ OK: verdi command available"
            else
                echo "   ❌ ERROR: verdi command not found"
            fi
            conda deactivate
        else
            echo "   ❌ ERROR: Environment '${CONDA_ENV_NAME}' does not exist"
            echo "   💡 Run: bash setup_aiida_profile.sh to create it"
        fi
    else
        echo "   ❌ ERROR: Conda not installed"
    fi
fi
echo ""

echo "4. PostgreSQL Status"
if command -v pg_isready &> /dev/null; then
    if pg_isready -h "$DB_HOST" -p "$DB_PORT" &> /dev/null; then
        echo "   ✅ OK: PostgreSQL is running on port $DB_PORT"
    else
        echo "   ❌ WARNING: PostgreSQL is not running on port $DB_PORT"
        echo "   💡 Run: bash setup_aiida_profile.sh to start it"
    fi
else
    echo "   ❌ WARNING: PostgreSQL client not found"
fi
echo ""

echo "5. RabbitMQ Status"
if command -v rabbitmqctl &> /dev/null; then
    if rabbitmqctl status 2>&1 | grep -q "rabbit.*running"; then
        echo "   ✅ OK: RabbitMQ is running"
    else
        echo "   ❌ WARNING: RabbitMQ is not running"
        echo "   💡 Run: bash setup_aiida_profile.sh to start it"
    fi
else
    echo "   ❌ WARNING: RabbitMQ not installed"
    echo "   💡 Run: bash setup_aiida_profile.sh to install it"
fi
echo ""

echo "========================================="
echo "  Recommended Actions"
echo "========================================="
echo ""

if [[ ! -w "$(dirname "$DB_PATH")" ]]; then
    echo "⚠️  Database path is not writable."
    echo "   The script will automatically use /tmp directories as fallback."
    echo ""
fi

echo ">>> To start the complete setup, run:"
echo "   bash setup_aiida_profile.sh"
echo ""

echo ">>> To check configuration only, run:"
echo "   bash scripts/init_aiida.sh --validate"
echo ""

echo ">>> To run individual modules:"
echo "   bash scripts/init_aiida.sh --env        # Environment variables"
echo "   bash scripts/init_aiida.sh --conda     # Conda environment"
echo "   bash scripts/init_aiida.sh --db         # Database & MQ"
echo "   bash scripts/init_aiida.sh --profile   # AiiDA profile"
echo ""

echo "========================================="
echo "  Done!"
echo "========================================="
