# AiiDA Ubuntu Quickstart

简体中文 | [English](#english)

---

## 目录

- [项目简介](#项目简介)
- [主要特性](#主要特性)
- [快速开始](#快速开始)
  - [方式一：一键安装](#方式一一键安装)
  - [方式二：分步运行](#方式二分步运行)
- [配置说明](#配置说明)
- [目录结构](#目录结构)
- [故障排除](#故障排除)
- [许可证](#许可证)

## 项目简介

AiiDA Ubuntu Quickstart 是一个自动化脚本工具，用于在 Ubuntu/Linux 系统上快速部署和配置 AiiDA 工作流管理系统。该项目通过模块化的脚本设计，简化了 AiiDA 环境搭建、数据库配置、消息队列设置以及用户档案创建等复杂流程。

AiiDA（Automated Interactive Infrastructure and Database for Computational Modelling）是一款开源的工作流管理系统，广泛应用于计算材料科学、计算化学和人工智能驱动的科学研究领域。它提供了可重现、自动记录和可扩展的科学工作流管理能力。

## 主要特性

- **自动化环境配置**：自动创建和管理 Conda 虚拟环境
- **模块化设计**：将复杂的安装过程拆分为独立的脚本模块
- **配置驱动**：通过 `config.env` 文件集中管理所有配置参数
- **数据库管理**：自动配置 PostgreSQL 数据库
- **消息队列集成**：集成 RabbitMQ 消息队列服务
- **用户档案管理**：自动化 AiiDA 用户档案创建和配置
- **错误处理**：完善的错误检查和诊断功能
- **灵活的执行方式**：支持一键执行或单独运行各个模块

## 快速开始

### 方式一：一键安装

一键安装脚本将自动执行所有配置步骤，适合首次部署或快速体验。

#### 前置要求

- Ubuntu 18.04+ 或其他 Linux 发行版
- Conda (Miniconda 或 Anaconda) 已安装
- PostgreSQL 已安装
- RabbitMQ Server 已安装
- Git 已安装
- Python 3.8+ 环境

#### 安装步骤

1. **克隆项目仓库**

   ```bash
   git clone <repository_url>
   cd aiida-ubuntu-quickstart
   ```

2. **配置环境参数**

   编辑 `config.env` 文件，根据您的环境配置以下参数：

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

   ⚠️ **重要提示**：请务必修改以下敏感信息：
   - `DB_PASSWORD`：设置强密码
   - `USER_EMAIL`：使用您的真实邮箱
   - `USER_FIRSTNAME` 和 `USER_LASTNAME`：填入您的姓名
   - `USER_INSTITUTION`：填写您的机构名称

3. **运行一键安装脚本**

   ```bash
   chmod +x setup_aiida_profile.sh
   ./setup_aiida_profile.sh
   ```

   脚本将显示配置摘要并等待确认，按 `y` 继续执行：

   ```
   AiiDA Profile Setup
   ===================

   Configuration Summary:
   ---------------------
     Conda Environment:
       - Name: aiida_test
       - Python Version: 3.10
       - Packages: aiida-core aiida-vasp
     ...
   
   Continue with setup? (y/n)
   ```

4. **验证安装结果**

   安装完成后，激活 Conda 环境并检查状态：

   ```bash
   conda activate aiida_test
   verdi status
   ```

   正常情况下应显示所有服务运行状态为绿色。

### 方式二：分步运行

分步运行允许您逐个执行各个模块，便于调试和自定义配置。

#### 步骤 1：验证配置

在执行任何模块之前，首先验证配置文件的正确性：

```bash
bash scripts/init_aiida.sh --validate
```

#### 步骤 2：环境变量加载

加载并验证环境变量配置：

```bash
bash scripts/01-env_loader.sh
```

此脚本将读取 `config.env` 文件并验证所有必需的配置项。

#### 步骤 3：Conda 环境管理

创建或更新 Conda 虚拟环境：

```bash
bash scripts/02-conda_manager.sh
```

此脚本执行以下操作：
- 检查 Conda 环境是否存在
- 如不存在，创建新环境并安装指定包
- 如已存在，验证包版本是否匹配
- 如版本不匹配，自动更新包

#### 步骤 4：数据库和消息队列配置

配置 PostgreSQL 数据库和 RabbitMQ 消息队列：

```bash
bash scripts/03-db_mq_config.sh
```

此脚本执行以下操作：
- 检查 PostgreSQL 是否运行
- 如未运行，自动启动 PostgreSQL 服务
- 创建数据库用户（如不存在）
- 创建数据库（如不存在）
- 验证数据库连接

#### 步骤 5：AiiDA 档案配置

创建和配置 AiiDA 用户档案：

```bash
bash scripts/04-aiida_profile.sh
```

此脚本执行以下操作：
- 创建 AiiDA 用户（如不存在）
- 创建 AiiDA 档案
- 配置数据库连接
- 配置消息队列连接
- 设置默认档案

#### 步骤 6：诊断检查（可选）

运行诊断脚本检查系统状态：

```bash
bash scripts/05-diagnose.sh
```

## 配置说明

### 必需配置项

| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| `CONDA_ENV_NAME` | Conda 环境名称 | `aiida_test` |
| `CONDA_PYTHON_VERSION` | Python 版本 | `3.10` |
| `CONDA_PACKAGES` | 需安装的包（空格分隔） | `aiida-core aiida-vasp` |
| `DB_HOST` | 数据库主机地址 | `127.0.0.1` |
| `DB_PORT` | 数据库端口 | `5432` |
| `DB_USERNAME` | 数据库用户名 | `aiida_user` |
| `DB_PASSWORD` | 数据库密码 | `your_password` |
| `DB_NAME` | 数据库名称 | `aiida_db` |
| `DB_PATH` | PostgreSQL 数据目录路径 | `/home/user/data/postgresql/db` |
| `USER_EMAIL` | AiiDA 用户邮箱 | `user@example.com` |
| `USER_FIRSTNAME` | 用户名 | `YourFirstName` |
| `USER_LASTNAME` | 用户姓氏 | `YourLastName` |
| `USER_INSTITUTION` | 所属机构 | `YourInstitution` |
| `PROFILE_NAME` | AiiDA 档案名称 | `aiida_profile` |
| `PROFILE_REPOSITORY_URI` | 档案仓库 URI | `file:///home/user/data/aiida_profile` |

### 可选配置项

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `CONDA_CHANNELS` | Conda 渠道 | `conda-forge` |
| `RABBITMQ_VERSION` | RabbitMQ 版本 | `3.8.3` |

## 目录结构

```
aiida-ubuntu-quickstart/
├── config.env                 # 配置文件
├── profile.yaml              # 档案配置模板
├── setup_aiida_profile.sh    # 一键安装脚本
├── README.md                 # 项目说明文档
├── TEST_GUIDE.md             # 测试指南
└── scripts/
    ├── init_aiida.sh         # 主初始化脚本
    ├── 01-env_loader.sh      # 环境变量加载模块
    ├── 02-conda_manager.sh   # Conda 环境管理模块
    ├── 03-db_mq_config.sh     # 数据库和消息队列配置模块
    ├── 04-aiida_profile.sh    # AiiDA 档案配置模块
    └── 05-diagnose.sh        # 诊断检查模块
```

## 故障排除

### 常见问题

#### 1. PostgreSQL 连接失败

**症状**：数据库连接错误

**解决方案**：
- 检查 PostgreSQL 服务是否正在运行：`pg_isready`
- 验证端口配置是否正确：`grep port /path/to/postgresql.conf`
- 检查防火墙设置：`sudo ufw allow 5432/tcp`

#### 2. Conda 环境激活失败

**症状**：无法激活 Conda 环境

**解决方案**：
- 确保 Conda 已正确安装：`conda --version`
- 初始化 Conda：`conda init bash`
- 重新加载 shell 配置：`source ~/.bashrc`

#### 3. AiiDA 档案创建失败

**症状**：verdi profile setup 命令失败

**解决方案**：
- 确认数据库已正确创建并可访问
- 检查用户名和密码是否正确
- 验证 RabbitMQ 服务是否运行：`rabbitmqctl status`

#### 4. 包版本不匹配

**症状**：某些包无法正常工作

**解决方案**：
- 更新所有包：`pip install --upgrade <package_name>`
- 或删除并重新创建 Conda 环境

### 诊断工具

使用诊断脚本进行全面检查：

```bash
bash scripts/05-diagnose.sh
```

此脚本将检查：
- Conda 环境状态
- PostgreSQL 服务状态
- RabbitMQ 服务状态
- AiiDA 配置状态
- 网络连接状态

## 许可证

本项目遵循 MIT 许可证。详情请参阅 LICENSE 文件。

---

<a id="english"></a>

# AiiDA Ubuntu Quickstart

[中文](#项目简介) | English

---

## Table of Contents

- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
  - [Method 1: One-Click Installation](#method-1-one-click-installation)
  - [Method 2: Step-by-Step Execution](#method-2-step-by-step-execution)
- [Configuration Reference](#configuration-reference)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Project Overview

AiiDA Ubuntu Quickstart is an automation toolkit designed to rapidly deploy and configure the AiiDA workflow management system on Ubuntu/Linux systems. The project simplifies the complex process of setting up AiiDA environments through a modular script architecture, handling database configuration, message queue setup, and user profile creation automatically.

AiiDA (Automated Interactive Infrastructure and Database for Computational Modelling) is an open-source workflow management system widely used in computational materials science, computational chemistry, and AI-driven scientific research. It provides reproducible, automatically documented, and scalable scientific workflow management capabilities.

## Key Features

- **Automated Environment Configuration**: Automatically creates and manages Conda virtual environments
- **Modular Design**: Splits complex installation into independent script modules
- **Configuration-Driven**: Centralized configuration management via `config.env`
- **Database Management**: Automated PostgreSQL database configuration
- **Message Queue Integration**: Integrated RabbitMQ message queue service
- **User Profile Management**: Automated AiiDA user profile creation and configuration
- **Error Handling**: Comprehensive error checking and diagnostic capabilities
- **Flexible Execution**: Supports one-click execution or individual module runs

## Quick Start

### Method 1: One-Click Installation

The one-click installation script automatically executes all configuration steps, suitable for initial deployment or quick setup.

#### Prerequisites

- Ubuntu 18.04+ or other Linux distributions
- Conda (Miniconda or Anaconda) installed
- PostgreSQL installed
- RabbitMQ Server installed
- Git installed
- Python 3.8+ environment

#### Installation Steps

1. **Clone the repository**

   ```bash
   git clone <repository_url>
   cd aiida-ubuntu-quickstart
   ```

2. **Configure environment parameters**

   Edit the `config.env` file and configure the following parameters according to your environment:

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

   ⚠️ **Important**: Please make sure to modify the following sensitive information:
   - `DB_PASSWORD`: Set a strong password
   - `USER_EMAIL`: Use your real email address
   - `USER_FIRSTNAME` and `USER_LASTNAME`: Enter your name
   - `USER_INSTITUTION`: Fill in your institution name

3. **Run the one-click installation script**

   ```bash
   chmod +x setup_aiida_profile.sh
   ./setup_aiida_profile.sh
   ```

   The script will display a configuration summary and wait for confirmation. Press `y` to continue:

   ```
   AiiDA Profile Setup
   ===================

   Configuration Summary:
   ---------------------
     Conda Environment:
       - Name: aiida_test
       - Python Version: 3.10
       - Packages: aiida-core aiida-vasp
     ...
   
   Continue with setup? (y/n)
   ```

4. **Verify the installation**

   After installation, activate the Conda environment and check the status:

   ```bash
   conda activate aiida_test
   verdi status
   ```

   Normally, all services should show green status indicators.

### Method 2: Step-by-Step Execution

Step-by-step execution allows you to run each module individually, facilitating debugging and custom configuration.

#### Step 1: Validate Configuration

Before executing any modules, first validate the configuration file:

```bash
bash scripts/init_aiida.sh --validate
```

#### Step 2: Load Environment Variables

Load and validate environment variable configuration:

```bash
bash scripts/01-env_loader.sh
```

This script reads and validates all required configuration items from the `config.env` file.

#### Step 3: Conda Environment Management

Create or update the Conda virtual environment:

```bash
bash scripts/02-conda_manager.sh
```

This script performs the following operations:
- Check if the Conda environment exists
- If not exists, create a new environment and install specified packages
- If exists, validate package versions
- If versions don't match, automatically update packages

#### Step 4: Database and Message Queue Configuration

Configure PostgreSQL database and RabbitMQ message queue:

```bash
bash scripts/03-db_mq_config.sh
```

This script performs the following operations:
- Check if PostgreSQL is running
- If not running, automatically start PostgreSQL service
- Create database user (if not exists)
- Create database (if not exists)
- Validate database connection

#### Step 5: AiiDA Profile Configuration

Create and configure AiiDA user profile:

```bash
bash scripts/04-aiida_profile.sh
```

This script performs the following operations:
- Create AiiDA user (if not exists)
- Create AiiDA profile
- Configure database connection
- Configure message queue connection
- Set default profile

#### Step 6: Diagnostic Check (Optional)

Run diagnostic script to check system status:

```bash
bash scripts/05-diagnose.sh
```

## Configuration Reference

### Required Configuration Items

| Configuration Item | Description | Example Value |
|---------------------|-------------|---------------|
| `CONDA_ENV_NAME` | Conda environment name | `aiida_test` |
| `CONDA_PYTHON_VERSION` | Python version | `3.10` |
| `CONDA_PACKAGES` | Packages to install (space-separated) | `aiida-core aiida-vasp` |
| `DB_HOST` | Database host address | `127.0.0.1` |
| `DB_PORT` | Database port | `5432` |
| `DB_USERNAME` | Database username | `aiida_user` |
| `DB_PASSWORD` | Database password | `your_password` |
| `DB_NAME` | Database name | `aiida_db` |
| `DB_PATH` | PostgreSQL data directory path | `/home/user/data/postgresql/db` |
| `USER_EMAIL` | AiiDA user email | `user@example.com` |
| `USER_FIRSTNAME` | User first name | `YourFirstName` |
| `USER_LASTNAME` | User last name | `YourLastName` |
| `USER_INSTITUTION` | Institution | `YourInstitution` |
| `PROFILE_NAME` | AiiDA profile name | `aiida_profile` |
| `PROFILE_REPOSITORY_URI` | Profile repository URI | `file:///home/user/data/aiida_profile` |

### Optional Configuration Items

| Configuration Item | Description | Default Value |
|--------------------|-------------|---------------|
| `CONDA_CHANNELS` | Conda channels | `conda-forge` |
| `RABBITMQ_VERSION` | RabbitMQ version | `3.8.3` |

## Project Structure

```
aiida-ubuntu-quickstart/
├── config.env                 # Configuration file
├── profile.yaml              # Profile configuration template
├── setup_aiida_profile.sh    # One-click installation script
├── README.md                 # Project documentation
├── TEST_GUIDE.md             # Test guide
└── scripts/
    ├── init_aiida.sh         # Main initialization script
    ├── 01-env_loader.sh      # Environment variable loader module
    ├── 02-conda_manager.sh   # Conda environment management module
    ├── 03-db_mq_config.sh     # Database and message queue configuration module
    ├── 04-aiida_profile.sh    # AiiDA profile configuration module
    └── 05-diagnose.sh        # Diagnostic check module
```

## Troubleshooting

### Common Issues

#### 1. PostgreSQL Connection Failed

**Symptoms**: Database connection error

**Solution**:
- Check if PostgreSQL service is running: `pg_isready`
- Verify port configuration: `grep port /path/to/postgresql.conf`
- Check firewall settings: `sudo ufw allow 5432/tcp`

#### 2. Conda Environment Activation Failed

**Symptoms**: Cannot activate Conda environment

**Solution**:
- Ensure Conda is correctly installed: `conda --version`
- Initialize Conda: `conda init bash`
- Reload shell configuration: `source ~/.bashrc`

#### 3. AiiDA Profile Creation Failed

**Symptoms**: verdi profile setup command failed

**Solution**:
- Confirm database is correctly created and accessible
- Check if username and password are correct
- Verify RabbitMQ service is running: `rabbitmqctl status`

#### 4. Package Version Mismatch

**Symptoms**: Some packages are not working properly

**Solution**:
- Update all packages: `pip install --upgrade <package_name>`
- Or delete and recreate the Conda environment

### Diagnostic Tools

Use the diagnostic script for comprehensive checking:

```bash
bash scripts/05-diagnose.sh
```

This script checks:
- Conda environment status
- PostgreSQL service status
- RabbitMQ service status
- AiiDA configuration status
- Network connection status

## License

This project is licensed under the MIT License. See the LICENSE file for details.
