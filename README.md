# AiiDA Ubuntu 一键部署脚本 / AiiDA Ubuntu Quickstart

[English](#english) | [中文](#中文)

---

## 中文

### 项目简介

AiiDA Ubuntu 一键部署脚本是一个自动化工具，用于在 Ubuntu/WSL 环境中快速部署完整的 AiiDA 计算科学工作流管理系统。该脚本自动化了 Conda 环境配置、PostgreSQL 数据库安装、RabbitMQ 消息队列配置以及 AiiDA Profile 设置等步骤。

### 主要特性

- **一键部署**：仅需一条命令即可完成所有组件的安装和配置
- **幂等性设计**：支持重复运行，自动检测并跳过已完成的步骤
- **智能包管理**：优先使用 pip 安装 AiiDA 包，失败时自动回退到 conda
- **自动验证**：部署完成后自动检查所有服务状态
- **详细日志**：完整的安装日志，方便问题排查

### 系统要求

- Ubuntu 18.04+ 或 WSL (Windows Subsystem for Linux)
- Conda (Miniconda 或 Anaconda)
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间

### 快速开始

#### 1. 克隆项目

```bash
git clone https://github.com/stillfast/aiida-ubuntu-quickstart.git
cd aiida-ubuntu-quickstart
```

#### 2. 修改配置文件

编辑 `config.env` 文件，根据需要修改以下配置：

```bash
# Conda 环境配置
CONDA_ENV_NAME=aiida                    # 环境名称
CONDA_PYTHON_VERSION=3.10              # Python 版本
CONDA_PACKAGES="aiida-vasp"             # 要安装的包（支持空格分隔多个包）

# 数据库配置
DB_HOST=127.0.0.1                       # 数据库主机
DB_PORT=5432                             # 数据库端口
DB_USERNAME=aiida_user                  # 数据库用户名
DB_PASSWORD=your_password                # 数据库密码
DB_NAME=aiida_db                        # 数据库名称
DB_PATH=/home/user/data/postgresql       # 数据库存储路径

# RabbitMQ 配置
RABBITMQ_VERSION=3.8.3                 # RabbitMQ 版本

# 用户信息
USER_EMAIL=your@email.com               # AiiDA 用户邮箱
USER_FIRSTNAME=Your                     # 名字
USER_LASTNAME=Name                      # 姓氏
USER_INSTITUTION=YourInstitution        # 机构

# AiiDA Profile 配置
PROFILE_NAME=aiida_profile              # Profile 名称
PROFILE_REPOSITORY_URI=file:///home/user/data/aiida_profile  # 数据仓库路径
```

#### 3. 运行部署脚本

```bash
bash quickstart.sh
```

#### 4. 验证安装

部署完成后，运行以下命令验证：

```bash
conda activate aiida
verdi status
```

应该看到类似输出：

```
✔ version:     AiiDA v2.8.0
✔ config:      /home/user/.aiida
✔ profile:     aiida_profile
✔ storage:     Storage for 'aiida_profile' [open]
✔ broker:      RabbitMQ v3.8.3 @ amqp://guest:guest@127.0.0.1:5672
```

### 部署流程

脚本会自动执行以下步骤：

1. **创建 Conda 环境** - 创建指定 Python 版本的虚拟环境
2. **安装 AiiDA 包** - 优先 pip，失败则 conda
3. **安装 PostgreSQL** - 数据库管理系统
4. **安装 RabbitMQ** - 消息队列服务
5. **初始化数据库** - 配置数据库存储路径和端口
6. **启动 PostgreSQL** - 启动数据库服务
7. **创建数据库用户和数据库** - 设置数据库访问凭证
8. **配置 AiiDA Profile** - 创建 AiiDA 工作环境
9. **验证部署** - 检查所有服务状态

### 常见问题

#### Q1: 部署失败，提示数据库已存在

**原因**: 数据库中保留了旧数据

**解决方案**: 
1. 使用新的数据库名称（修改 `config.env` 中的 `DB_NAME`）
2. 或删除旧数据库：
   ```bash
   dropdb -h 127.0.0.1 -p 5432 -U aiida_user aiida_db
   ```

#### Q2: Python 版本不匹配

**原因**: RabbitMQ 安装时可能降级了 Python

**解决方案**: 脚本会自动修复，或手动执行：
```bash
conda install -n aiida python=3.10
```

#### Q3: RabbitMQ 启动失败

**原因**: 端口被占用或权限不足

**解决方案**:
```bash
# 检查 RabbitMQ 状态
rabbitmqctl status

# 重启 RabbitMQ
rabbitmqctl stop && rabbitmq-server -detached
```

#### Q4: verdi 命令找不到

**原因**: Conda 环境未激活

**解决方案**:
```bash
conda activate aiida
```

### 项目结构

```
aiida-ubuntu-quickstart/
├── README.md          # 本文件
├── config.env         # 配置文件
├── quickstart.sh      # 主部署脚本
└── logs/              # 安装日志目录
```

### 日志文件

所有安装日志都会保存在 `logs/` 目录中，文件名格式为：
```
aiida_install_YYYYMMDD_HHMMSS.log
```

### 卸载

如需卸载 AiiDA 环境：

```bash
# 删除 Conda 环境
conda env remove -n aiida

# 删除数据目录
rm -rf /home/user/data/postgresql
rm -rf /home/user/data/aiida_profile

# 删除 AiiDA 配置
rm -rf ~/.aiida
```

### 许可证

本项目采用 MIT 许可证。

### 贡献

欢迎提交 Issue 和 Pull Request！

### 联系方式

- GitHub Issues: https://github.com/stillfast/aiida-ubuntu-quickstart/issues

---

## English

### Project Overview

AiiDA Ubuntu Quickstart is an automation tool for quickly deploying a complete AiiDA computational science workflow management system in Ubuntu/WSL environments. The script automates Conda environment setup, PostgreSQL database installation, RabbitMQ message queue configuration, and AiiDA Profile setup.

### Key Features

- **One-command deployment**: Complete installation and configuration with a single command
- **Idempotent design**: Supports repeated runs, automatically detects and skips completed steps
- **Smart package management**: Prefers pip for AiiDA packages, falls back to conda on failure
- **Automatic verification**: Checks all service statuses after deployment
- **Detailed logging**: Complete installation logs for easy troubleshooting

### System Requirements

- Ubuntu 18.04+ or WSL (Windows Subsystem for Linux)
- Conda (Miniconda or Anaconda)
- At least 4GB available RAM
- At least 10GB available disk space

### Quick Start

#### 1. Clone the Project

```bash
git clone https://github.com/stillfast/aiida-ubuntu-quickstart.git
cd aiida-ubuntu-quickstart
```

#### 2. Modify Configuration

Edit the `config.env` file to customize your setup:

```bash
# Conda Environment
CONDA_ENV_NAME=aiida                    # Environment name
CONDA_PYTHON_VERSION=3.10              # Python version
CONDA_PACKAGES="aiida-vasp"             # Packages to install (space-separated)

# Database Configuration
DB_HOST=127.0.0.1                       # Database host
DB_PORT=5432                             # Database port
DB_USERNAME=aiida_user                  # Database username
DB_PASSWORD=your_password                # Database password
DB_NAME=aiida_db                        # Database name
DB_PATH=/home/user/data/postgresql       # Database storage path

# RabbitMQ Configuration
RABBITMQ_VERSION=3.8.3                 # RabbitMQ version

# User Information
USER_EMAIL=your@email.com               # AiiDA user email
USER_FIRSTNAME=Your                     # First name
USER_LASTNAME=Name                      # Last name
USER_INSTITUTION=YourInstitution        # Institution

# AiiDA Profile Configuration
PROFILE_NAME=aiida_profile              # Profile name
PROFILE_REPOSITORY_URI=file:///home/user/data/aiida_profile  # Repository path
```

#### 3. Run the Deployment Script

```bash
bash quickstart.sh
```

#### 4. Verify Installation

After deployment, verify with:

```bash
conda activate aiida
verdi status
```

You should see output similar to:

```
✔ version:     AiiDA v2.8.0
✔ config:      /home/user/.aiida
✔ profile:     aiida_profile
✔ storage:     Storage for 'aiida_profile' [open]
✔ broker:      RabbitMQ v3.8.3 @ amqp://guest:guest@127.0.0.1:5672
```

### Deployment Process

The script automatically performs these steps:

1. **Create Conda Environment** - Create virtual environment with specified Python version
2. **Install AiiDA Packages** - Prefer pip, fallback to conda on failure
3. **Install PostgreSQL** - Database management system
4. **Install RabbitMQ** - Message queue service
5. **Initialize Database** - Configure database storage path and port
6. **Start PostgreSQL** - Start database service
7. **Create Database User and Database** - Set up database credentials
8. **Configure AiiDA Profile** - Create AiiDA working environment
9. **Verify Deployment** - Check all service statuses

### Troubleshooting

#### Q1: Deployment fails with "database already exists"

**Cause**: Old data remains in the database

**Solution**: 
1. Use a new database name (modify `DB_NAME` in `config.env`)
2. Or delete the old database:
   ```bash
   dropdb -h 127.0.0.1 -p 5432 -U aiida_user aiida_db
   ```

#### Q2: Python version mismatch

**Cause**: RabbitMQ installation may downgrade Python

**Solution**: Script auto-fixes, or manually:
```bash
conda install -n aiida python=3.10
```

#### Q3: RabbitMQ fails to start

**Cause**: Port in use or insufficient permissions

**Solution**:
```bash
# Check RabbitMQ status
rabbitmqctl status

# Restart RabbitMQ
rabbitmqctl stop && rabbitmq-server -detached
```

#### Q4: verdi command not found

**Cause**: Conda environment not activated

**Solution**:
```bash
conda activate aiida
```

### Project Structure

```
aiida-ubuntu-quickstart/
├── README.md          # This file
├── config.env         # Configuration file
├── quickstart.sh      # Main deployment script
└── logs/              # Installation log directory
```

### Log Files

All installation logs are saved in the `logs/` directory with filename format:
```
aiida_install_YYYYMMDD_HHMMSS.log
```

### Uninstallation

To uninstall the AiiDA environment:

```bash
# Remove Conda environment
conda env remove -n aiida

# Remove data directories
rm -rf /home/user/data/postgresql
rm -rf /home/user/data/aiida_profile

# Remove AiiDA configuration
rm -rf ~/.aiida
```

### License

This project is licensed under the MIT License.

### Contributing

Issues and Pull Requests are welcome!

### Contact

- GitHub Issues: https://github.com/stillfast/aiida-ubuntu-quickstart/issues
