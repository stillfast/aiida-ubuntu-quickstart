#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# AiiDA + PostgreSQL + RabbitMQ 一键部署脚本
# 使用方式：chmod +x setup_aiida.sh && ./setup_aiida.sh
# ============================================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "错误：未找到配置文件 config.env，请确保它与脚本位于同一目录下。"
    exit 1
fi
source "$CONFIG_FILE"

# ----------------------------------------------------------------------------
# 日志系统
# ----------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/aiida_install_${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================================================"
echo "AiiDA 环境部署日志 - $(date '+%Y-%m-%d %H:%M:%S')"
echo "配置文件: $CONFIG_FILE"
echo "日志文件: $LOG_FILE"
echo "================================================================================"
echo ""

log_section() {
    echo ""
    echo "=== $1 ==="
    echo ""
}

# ----------------------------------------------------------------------------
# 辅助函数：初始化 Conda
# ----------------------------------------------------------------------------
init_conda() {
    if ! command -v conda &> /dev/null; then
        echo "错误：未检测到 conda 命令，请先安装 Miniconda 或 Anaconda。"
        exit 1
    fi
    # 初始化 conda 以便在脚本中使用 conda activate
    eval "$(conda shell.bash hook)"
    echo "Conda 已初始化，当前 base 环境: $CONDA_DEFAULT_ENV"
}

# ----------------------------------------------------------------------------
# 1. 创建 Conda 环境并安装 AiiDA 核心
# ----------------------------------------------------------------------------
setup_conda_env() {
    log_section "1. 创建 Conda 环境: ${CONDA_ENV_NAME} (Python ${CONDA_PYTHON_VERSION})"

    if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
        echo "环境 ${CONDA_ENV_NAME} 已存在，将激活并更新。"
    else
        conda create -n "${CONDA_ENV_NAME}" python="${CONDA_PYTHON_VERSION}" -y
    fi

    conda activate "${CONDA_ENV_NAME}"
    echo "当前环境: $(conda info --envs | grep '*' | awk '{print $1}')"
}

# ----------------------------------------------------------------------------
# 2. 安装 AiiDA 核心和插件（优先 pip，失败则 conda）
# ----------------------------------------------------------------------------
install_aiida_packages() {
    log_section "2. 安装 AiiDA 包: ${CONDA_PACKAGES}"

    # 检查环境是否已激活
    if [[ "$CONDA_DEFAULT_ENV" != "${CONDA_ENV_NAME}" ]]; then
        conda activate "${CONDA_ENV_NAME}"
    fi

    # 解析包列表
    IFS=' ' read -ra packages <<< "${CONDA_PACKAGES}"

    for package in "${packages[@]}"; do
        # 检查包是否已安装
        if pip show "$package" &> /dev/null; then
            echo "包 ${package} 已通过 pip 安装，跳过。"
            continue
        fi

        # 尝试使用 pip 安装
        echo "尝试使用 pip 安装 ${package}..."
        if pip install -q "$package" 2>/dev/null; then
            echo "包 ${package} 通过 pip 安装成功"
        else
            # pip 失败，使用 conda
            echo "pip 安装失败，尝试使用 conda 安装 ${package}..."
            if conda install -y -c conda-forge "$package" 2>/dev/null; then
                echo "包 ${package} 通过 conda 安装成功"
            else
                echo "警告：无法安装包 ${package}，跳过"
            fi
        fi
    done

    echo "AiiDA 包安装完成"
}

# ----------------------------------------------------------------------------
# 3. 安装 PostgreSQL
# ----------------------------------------------------------------------------
install_postgres() {
    log_section "3. 安装 PostgreSQL"

    # 检查 postgresql 是否已安装
    if command -v psql &> /dev/null; then
        PSQL_VERSION=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1)
        echo "PostgreSQL 已安装 (版本: $(psql --version 2>&1 | grep -oP '\d+\.\d+'))，跳过安装。"
        return 0
    fi

    conda install -c conda-forge postgresql -y
    echo "PostgreSQL 安装完成"
}

# ----------------------------------------------------------------------------
# 4. 安装 RabbitMQ (指定版本)
# ----------------------------------------------------------------------------
install_rabbitmq() {
    log_section "4. 安装 RabbitMQ ${RABBITMQ_VERSION}"

    # 检查 rabbitmq-server 是否已安装
    if command -v rabbitmq-server &> /dev/null; then
        RABBITMQ_INSTALLED_VERSION=$(rabbitmqctl version 2>/dev/null || echo "")
        echo "RabbitMQ 已安装 (版本: ${RABBITMQ_INSTALLED_VERSION})，跳过安装。"
        return 0
    fi

    conda install conda-forge::rabbitmq-server="${RABBITMQ_VERSION}" -y
    echo "RabbitMQ 安装完成"
}

# ----------------------------------------------------------------------------
# 4.5. 修复 Python 环境（RabbitMQ 可能会降级 Python）
# ----------------------------------------------------------------------------
fix_python_environment() {
    log_section "4.5. 修复 Python 环境"

    # 检查当前环境中的 Python 版本
    if [[ "$CONDA_DEFAULT_ENV" != "${CONDA_ENV_NAME}" ]]; then
        conda activate "${CONDA_ENV_NAME}"
    fi

    PYTHON_VERSION_CHECK=$(python --version 2>&1 | grep -oP '\d+\.\d+' || echo "")
    
    if [[ "$PYTHON_VERSION_CHECK" != "${CONDA_PYTHON_VERSION}" ]]; then
        echo "检测到 Python 版本不匹配 (当前: ${PYTHON_VERSION_CHECK}, 期望: ${CONDA_PYTHON_VERSION})"
        echo "重新安装 Python ${CONDA_PYTHON_VERSION}..."
        conda install -n "${CONDA_ENV_NAME}" python="${CONDA_PYTHON_VERSION}" -y
        echo "Python 环境修复完成"
    else
        echo "Python 版本正确，跳过修复"
    fi
}

# ----------------------------------------------------------------------------
# 5. 初始化 PostgreSQL 数据库
# ----------------------------------------------------------------------------
init_postgres_db() {
    log_section "5. 初始化 PostgreSQL 数据库目录"

    DB_PATH="${DB_PATH/#\~/$HOME}"   # 展开 ~
    mkdir -p "$DB_PATH"

    if [[ ! -f "${DB_PATH}/PG_VERSION" ]]; then
        echo "正在执行 initdb -D ${DB_PATH}"
        initdb -D "$DB_PATH"
    else
        echo "数据库目录已存在，跳过初始化。"
    fi

    # 修改 postgresql.conf 以监听所有地址（可选）
    CONF_FILE="${DB_PATH}/postgresql.conf"
    if grep -q "^#listen_addresses" "$CONF_FILE"; then
        sed -i "s/^#listen_addresses = .*/listen_addresses = '${DB_HOST}'/" "$CONF_FILE"
    elif ! grep -q "^listen_addresses" "$CONF_FILE"; then
        echo "listen_addresses = '${DB_HOST}'" >> "$CONF_FILE"
    fi

    # 设置端口
    if grep -q "^#port" "$CONF_FILE"; then
        sed -i "s/^#port = .*/port = ${DB_PORT}/" "$CONF_FILE"
    elif ! grep -q "^port" "$CONF_FILE"; then
        echo "port = ${DB_PORT}" >> "$CONF_FILE"
    fi

    echo "PostgreSQL 初始化完成"
}

# ----------------------------------------------------------------------------
# 6. 启动 PostgreSQL 服务
# ----------------------------------------------------------------------------
start_postgres() {
    log_section "6. 启动 PostgreSQL 服务 (端口 ${DB_PORT})"

    # 检查是否已经在运行
    if pg_isready -h "$DB_HOST" -p "$DB_PORT" &> /dev/null; then
        echo "PostgreSQL 已在运行，跳过启动。"
        return 0
    fi

    pg_ctl -D "$DB_PATH" -l "${DB_PATH}/logfile" start
    sleep 3

    if pg_isready -h "$DB_HOST" -p "$DB_PORT" &> /dev/null; then
        echo "PostgreSQL 启动成功"
    else
        echo "错误：PostgreSQL 启动失败，请查看日志 ${DB_PATH}/logfile"
        exit 1
    fi
}

# ----------------------------------------------------------------------------
# 7. 创建数据库用户和数据库
# ----------------------------------------------------------------------------
create_db_user_and_db() {
    log_section "7. 创建数据库用户 ${DB_USERNAME} 和数据库 ${DB_NAME}"

    # 检查用户是否存在
    USER_EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USERNAME}'" 2>/dev/null || echo "")
    if [[ "$USER_EXISTS" != "1" ]]; then
        echo "创建用户 ${DB_USERNAME}"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -c "CREATE USER ${DB_USERNAME} WITH PASSWORD '${DB_PASSWORD}';"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -c "ALTER USER ${DB_USERNAME} CREATEDB;"
    else
        echo "用户 ${DB_USERNAME} 已存在"
    fi

    # 检查数据库是否存在
    DB_EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || echo "")
    if [[ "$DB_EXISTS" != "1" ]]; then
        echo "创建数据库 ${DB_NAME}"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USERNAME};"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -c "ALTER DATABASE ${DB_NAME} SET timezone TO 'Asia/Shanghai';"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USERNAME};"
    else
        echo "数据库 ${DB_NAME} 已存在"
    fi

    echo "数据库配置完成"
}

# ----------------------------------------------------------------------------
# 8. 配置 AiiDA Profile (使用 verdi profile setup)
# ----------------------------------------------------------------------------
setup_aiida_profile() {
    log_section "9. 配置 AiiDA Profile: ${PROFILE_NAME}"

    # 确保 repository 目录存在
    PROFILE_REPOSITORY="${PROFILE_REPOSITORY_URI#file://}"
    mkdir -p "$PROFILE_REPOSITORY"

    # 检查 profile 是否已存在
    echo "=== 当前 Profile 列表 ==="
    verdi profile list
    echo ""

    # 检查 profile 是否存在（使用 verdi profile show 命令）
    if verdi profile show "${PROFILE_NAME}" &> /dev/null; then
        echo "Profile '${PROFILE_NAME}' 已存在，跳过创建。"
        echo ""
        echo "=== 设置 ${PROFILE_NAME} 为默认 Profile ==="
        verdi profile set-default "${PROFILE_NAME}"
    else
        # 检查数据库中是否有旧数据
        echo "=== 检查数据库 ${DB_NAME} ==="
        DB_HAS_DATA=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM db_dbsetting LIMIT 1" 2>/dev/null || echo "0")
        
        if [[ "$DB_HAS_DATA" -gt 0 ]]; then
            echo "警告：数据库 ${DB_NAME} 中已有数据（${DB_HAS_DATA} 条记录）"
            echo "这可能会导致 profile 创建失败（唯一键冲突）"
            echo ""
            echo "建议："
            echo "1. 使用新的数据库名称"
            echo "2. 或删除数据库后重新创建"
            echo "3. 或删除旧的 profile 配置"
            echo ""
            read -p "是否继续尝试创建 profile？可能会失败 (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "已取消 profile 创建。请先清理数据库或使用新的数据库名称。"
                return 1
            fi
        fi

        # 构建 verdi 命令
        PROFILE_CMD="verdi profile setup core.psql_dos -n \
            --profile-name ${PROFILE_NAME} \
            ${PROFILE_SET_DEFAULT} \
            --email ${USER_EMAIL} \
            --first-name ${USER_FIRSTNAME} \
            --last-name ${USER_LASTNAME} \
            --institution \"${USER_INSTITUTION}\" \
            --use-rabbitmq \
            --database-username ${DB_USERNAME} \
            --database-password ${DB_PASSWORD} \
            --database-name ${DB_NAME} \
            --database-engine postgresql_psycopg \
            --database-hostname ${DB_HOST} \
            --database-port ${DB_PORT} \
            --repository-uri \"${PROFILE_REPOSITORY_URI}\""

        echo "=== 创建 Profile ${PROFILE_NAME} ==="
        echo "执行命令: $PROFILE_CMD"
        eval "$PROFILE_CMD"
        echo ""
        echo "Profile '${PROFILE_NAME}' 创建成功"
    fi

    echo ""
    echo "=== 最终 Profile 状态 ==="
    verdi profile list
    echo ""
    echo "=== AiiDA 服务状态 ==="
    verdi status
}

# ----------------------------------------------------------------------------
# 主执行流程
# ----------------------------------------------------------------------------
main() {
    init_conda
    setup_conda_env
    install_aiida_packages
    install_postgres
    install_rabbitmq
    init_postgres_db
    start_postgres
    create_db_user_and_db
    setup_aiida_profile

    log_section "部署完成"
    echo "所有组件已安装并配置完毕。"
    echo "您可以运行以下命令激活环境并开始使用 AiiDA："
    echo "  conda activate ${CONDA_ENV_NAME}"
    echo "  verdi status"
}

# 执行主函数
main
