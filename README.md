# AiiDA Ubuntu Quickstart

简体中文 | [English](#english)

---

## 项目简介

AiiDA Ubuntu Quickstart 是一个自动化脚本工具，用于在 Ubuntu/Linux 系统上快速部署和配置 AiiDA 工作流管理系统。通过模块化脚本设计，自动完成环境搭建、数据库配置、消息队列设置以及用户档案创建。

**AiiDA**（Automated Interactive Infrastructure and Database for Computational Modelling）是一款开源的工作流管理系统，广泛应用于计算材料科学、计算化学和人工智能驱动的科学研究领域。

## 快速开始

### 唯一的前置要求

- **Conda** (Miniconda 或 Anaconda) 已安装

脚本会自动安装并配置：
- ✅ Conda 虚拟环境
- ✅ PostgreSQL 数据库
- ✅ RabbitMQ 消息队列
- ✅ AiiDA 及其插件

### 一键安装（推荐）

```bash
git clone <repository_url>
cd aiida-ubuntu-quickstart
bash setup_aiida_profile.sh
```

安装完成后：

```bash
conda activate <your_environment_name>
verdi status
```

### 分步执行

如需单独运行某个模块：

```bash
# 验证配置
bash scripts/init_aiida.sh --validate

# 环境变量加载
bash scripts/01-env_loader.sh

# Conda 环境管理
bash scripts/02-conda_manager.sh

# 数据库和消息队列配置
bash scripts/03-db_mq_config.sh

# AiiDA 档案配置
bash scripts/04-aiida_profile.sh

# 诊断检查（可选）
bash scripts/05-diagnose.sh
```

## 配置说明

编辑 `config.env` 文件，配置您的环境参数：

```bash
# Conda 环境配置
CONDA_ENV_NAME=aiida_test
CONDA_PYTHON_VERSION=3.10
CONDA_PACKAGES=aiida-core aiida-vasp
CONDA_CHANNELS=conda-forge

# 数据库配置
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=aiida_user
DB_PASSWORD=your_password
DB_NAME=aiida_db
DB_PATH=/home/username/data/postgresql/mylocal_db

# RabbitMQ 配置
RABBITMQ_VERSION=3.8.3

# 用户信息（请替换为您的真实信息）
USER_EMAIL=your.email@example.com
USER_FIRSTNAME=YourFirstName
USER_LASTNAME=YourLastName
USER_INSTITUTION=YourInstitution

# AiiDA 档案配置
PROFILE_NAME=aiida_profile
PROFILE_REPOSITORY_URI=file:///home/username/data/aiida_profile/profile
```

### 必需配置项说明

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `CONDA_ENV_NAME` | Conda 环境名称 | `aiida_test` |
| `CONDA_PYTHON_VERSION` | Python 版本 | `3.10` |
| `CONDA_PACKAGES` | 需安装的包 | `aiida-core aiida-vasp` |
| `DB_HOST` | 数据库主机 | `127.0.0.1` |
| `DB_PORT` | 数据库端口 | `5432` |
| `DB_USERNAME` | 数据库用户名 | `aiida_user` |
| `DB_PASSWORD` | **数据库密码** | `your_password` |
| `DB_NAME` | 数据库名称 | `aiida_db` |
| `DB_PATH` | PostgreSQL 数据目录 | `/home/username/data/postgresql/db` |
| `USER_EMAIL` | **用户邮箱** | `user@example.com` |
| `USER_FIRSTNAME` | **用户名** | `YourFirstName` |
| `USER_LASTNAME` | **用户姓氏** | `YourLastName` |
| `USER_INSTITUTION` | **所属机构** | `YourInstitution` |
| `PROFILE_NAME` | AiiDA 档案名称 | `aiida_profile` |
| `PROFILE_REPOSITORY_URI` | 档案仓库路径 | `file:///home/username/data/aiida_profile` |

⚠️ **请务必修改带粗体的敏感信息**

## 目录结构

```
aiida-ubuntu-quickstart/
├── config.env                 # 配置文件
├── setup_aiida_profile.sh    # 一键安装脚本
├── README.md                 # 项目说明文档
├── logs/                     # 日志目录
│   ├── aiida_setup_*.log    # 安装日志
│   └── rabbitmq/             # RabbitMQ 日志
└── scripts/
    ├── init_aiida.sh         # 主初始化脚本
    ├── 01-env_loader.sh      # 环境变量加载
    ├── 02-conda_manager.sh   # Conda 环境管理
    ├── 03-db_mq_config.sh    # 数据库和消息队列
    ├── 04-aiida_profile.sh   # AiiDA 档案配置
    └── 05-diagnose.sh        # 诊断检查
```

## 日志与故障排除

### 日志位置

安装过程会自动记录日志：

```bash
# 主日志
cat logs/aiida_setup_*.log

# RabbitMQ 日志
cat logs/rabbitmq/rabbitmq_startup.log
```

### 常见问题

#### 1. PostgreSQL 连接失败

```bash
# 检查服务状态
pg_isready

# 检查端口
grep port /path/to/postgresql.conf
```

#### 2. RabbitMQ 连接失败

```bash
# 检查 RabbitMQ 状态
rabbitmqctl status

# 重新启动 RabbitMQ
rabbitmq-server -detached
```

#### 3. Conda 环境问题

```bash
# 初始化 Conda
conda init bash
source ~/.bashrc
```

### 诊断工具

```bash
bash scripts/05-diagnose.sh
```

## 许可证

MIT License

---

<a id="english"></a>

# AiiDA Ubuntu Quickstart

[中文](#项目简介) | English

---

## Project Overview

AiiDA Ubuntu Quickstart is an automation toolkit for rapidly deploying and configuring the AiiDA workflow management system on Ubuntu/Linux. The modular scripts automatically handle environment setup, database configuration, message queue setup, and user profile creation.

**AiiDA** (Automated Interactive Infrastructure and Database for Computational Modelling) is an open-source workflow management system widely used in computational materials science, computational chemistry, and AI-driven scientific research.

## Quick Start

### Only Prerequisite

- **Conda** (Miniconda or Anaconda) installed

The script will automatically install and configure:
- ✅ Conda virtual environment
- ✅ PostgreSQL database
- ✅ RabbitMQ message queue
- ✅ AiiDA and plugins

### One-Click Installation (Recommended)

```bash
git clone <repository_url>
cd aiida-ubuntu-quickstart
bash setup_aiida_profile.sh
```

After installation:

```bash
conda activate <your_environment_name>
verdi status
```

### Step-by-Step Execution

To run individual modules:

```bash
# Validate configuration
bash scripts/init_aiida.sh --validate

# Load environment variables
bash scripts/01-env_loader.sh

# Manage Conda environment
bash scripts/02-conda_manager.sh

# Configure database and message queue
bash scripts/03-db_mq_config.sh

# Configure AiiDA profile
bash scripts/04-aiida_profile.sh

# Diagnostic check (optional)
bash scripts/05-diagnose.sh
```

## Configuration

Edit the `config.env` file to configure your environment:

```bash
# Conda Environment Configuration
CONDA_ENV_NAME=aiida_test
CONDA_PYTHON_VERSION=3.10
CONDA_PACKAGES=aiida-core aiida-vasp
CONDA_CHANNELS=conda-forge

# Database Configuration
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=aiida_user
DB_PASSWORD=your_password
DB_NAME=aiida_db
DB_PATH=/home/username/data/postgresql/mylocal_db

# RabbitMQ Configuration
RABBITMQ_VERSION=3.8.3

# User Information (Please replace with your actual information)
USER_EMAIL=your.email@example.com
USER_FIRSTNAME=YourFirstName
USER_LASTNAME=YourLastName
USER_INSTITUTION=YourInstitution

# AiiDA Profile Configuration
PROFILE_NAME=aiida_profile
PROFILE_REPOSITORY_URI=file:///home/username/data/aiida_profile/profile
```

### Required Configuration Items

| Configuration Item | Description | Example |
|--------------------|-------------|---------|
| `CONDA_ENV_NAME` | Conda environment name | `aiida_test` |
| `CONDA_PYTHON_VERSION` | Python version | `3.10` |
| `CONDA_PACKAGES` | Packages to install | `aiida-core aiida-vasp` |
| `DB_HOST` | Database host | `127.0.0.1` |
| `DB_PORT` | Database port | `5432` |
| `DB_USERNAME` | Database username | `aiida_user` |
| `DB_PASSWORD` | **Database password** | `your_password` |
| `DB_NAME` | Database name | `aiida_db` |
| `DB_PATH` | PostgreSQL data directory | `/home/username/data/postgresql/db` |
| `USER_EMAIL` | **User email** | `user@example.com` |
| `USER_FIRSTNAME` | **User first name** | `YourFirstName` |
| `USER_LASTNAME` | **User last name** | `YourLastName` |
| `USER_INSTITUTION` | **Institution** | `YourInstitution` |
| `PROFILE_NAME` | AiiDA profile name | `aiida_profile` |
| `PROFILE_REPOSITORY_URI` | Profile repository path | `file:///home/username/data/aiida_profile` |

⚠️ **Please modify the items in bold with your actual information**

## Project Structure

```
aiida-ubuntu-quickstart/
├── config.env                 # Configuration file
├── setup_aiida_profile.sh    # One-click installation script
├── README.md                 # Project documentation
├── logs/                     # Log directory
│   ├── aiida_setup_*.log    # Installation logs
│   └── rabbitmq/             # RabbitMQ logs
└── scripts/
    ├── init_aiida.sh         # Main initialization script
    ├── 01-env_loader.sh      # Environment variable loader
    ├── 02-conda_manager.sh   # Conda environment manager
    ├── 03-db_mq_config.sh    # Database and message queue
    ├── 04-aiida_profile.sh   # AiiDA profile configuration
    └── 05-diagnose.sh        # Diagnostic check
```

## Logging and Troubleshooting

### Log Locations

Installation process automatically logs to files:

```bash
# Main log
cat logs/aiida_setup_*.log

# RabbitMQ log
cat logs/rabbitmq/rabbitmq_startup.log
```

### Common Issues

#### 1. PostgreSQL Connection Failed

```bash
# Check service status
pg_isready

# Check port configuration
grep port /path/to/postgresql.conf
```

#### 2. RabbitMQ Connection Failed

```bash
# Check RabbitMQ status
rabbitmqctl status

# Restart RabbitMQ
rabbitmq-server -detached
```

#### 3. Conda Environment Issues

```bash
# Initialize Conda
conda init bash
source ~/.bashrc
```

### Diagnostic Tool

```bash
bash scripts/05-diagnose.sh
```

## License

MIT License
