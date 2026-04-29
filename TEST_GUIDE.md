# 测试指南 - Ubuntu 上的 PostgreSQL 和 RabbitMQ 自动设置

## 快速开始

### 1. 首次运行完整设置

```bash
cd install/aiida-ubuntu-quickstart
bash setup_aiida_profile.sh
```

脚本将自动：
- ✅ 创建 conda 虚拟环境（如果不存在）
- ✅ 安装 PostgreSQL（如果未安装）
- ✅ 启动 PostgreSQL 服务器（如果未运行）
- ✅ 创建数据库和用户（如果不存在）
- ✅ 安装 RabbitMQ（如果未安装）
- ✅ 启动 RabbitMQ 服务器（如果未运行）
- ✅ 配置 RabbitMQ 用户和 vhost（如果不存在）
- ✅ 创建 AiiDA profile

### 2. 单独测试 PostgreSQL 脚本

```bash
cd install/aiida-ubuntu-quickstart
bash scripts/01-validate-postgresql.sh
```

这个脚本会：
- 检查 PostgreSQL 是否已安装
- 如果未安装，通过 conda 自动安装
- 检查 PostgreSQL 服务器是否在运行
- 如果未运行，自动启动
- 检查数据库和用户是否存在
- 如果不存在，自动创建

### 3. 单独测试 RabbitMQ 脚本

```bash
cd install/aiida-ubuntu-quickstart
bash scripts/02-validate-rabbitmq.sh
```

这个脚本会：
- 检查 RabbitMQ 是否已安装
- 如果未安装，通过 conda 自动安装
- 检查 RabbitMQ 服务器是否在运行
- 如果未运行，自动启动
- 检查用户和 vhost 是否存在
- 如果不存在，自动创建

### 4. 反复运行的特性

这些脚本设计为可以**安全地反复运行**：
- ✅ 幂等性：多次运行结果相同
- ✅ 增量配置：只创建缺失的部分
- ✅ 状态检查：跳过已配置的项目
- ✅ 调试友好：清晰的日志输出

## Debug 步骤

### 查看脚本执行过程

添加调试输出：
```bash
bash -x setup_aiida_profile.sh
```

### 单独调试 PostgreSQL

```bash
# 查看 PostgreSQL 状态
pg_isready -h 127.0.0.1 -p 5432

# 查看数据库目录
ls -la ~/mylocal_db/

# 查看日志
cat ~/mylocal_db/logfile

# 手动启动
pg_ctl -D ~/mylocal_db -o "-p 5432" -l ~/mylocal_db/logfile start
```

### 单独调试 RabbitMQ

```bash
# 查看端口是否监听
nc -z 127.0.0.1 5672 && echo "Port 5672 is open"

# 查看 RabbitMQ 状态
rabbitmqctl status

# 停止并重启
rabbitmqctl stop
rabbitmq-server -detached

# 查看日志
cat $HOME/.rabbitmq/log/*.log
```

## 配置说明

### 配置文件：config.env

默认配置位于 `config.env`：

```env
# 数据库配置
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=aiida_user
DB_PASSWORD=123
DB_NAME=aiida_db

# RabbitMQ 配置
RABBITMQ_HOST=127.0.0.1
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=aiida
RABBITMQ_PASSWORD=123
RABBITMQ_VHOST=aiida
```

### 自定义配置

创建自定义配置文件 `config-custom.env`：

```env
# 数据库配置
DB_HOST=127.0.0.1
DB_PORT=5433
DB_USERNAME=my_user
DB_PASSWORD=my_password
DB_NAME=my_database
DB_DATA_DIR=$HOME/my_postgres_data

# RabbitMQ 配置
RABBITMQ_HOST=127.0.0.1
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=my_rabbit_user
RABBITMQ_PASSWORD=my_rabbit_password
RABBITMQ_VHOST=my_vhost
```

然后修改脚本以使用自定义配置。

## 常见问题

### Q1: PostgreSQL 启动失败，提示 "port already in use"

**解决方案：**
```bash
# 查看哪个进程占用了端口
lsof -i :5432

# 或者使用不同的端口
# 修改 config.env 中的 DB_PORT 为 5433
```

### Q2: RabbitMQ 启动失败，提示 "unable to connect to epmd"

**解决方案：**
```bash
# 确保 EPMD 正在运行
epmd -daemon

# 然后重新启动 RabbitMQ
rabbitmq-server -detached
```

### Q3: 脚本在安装步骤卡住

**解决方案：**
```bash
# 手动安装 PostgreSQL
conda install -c conda-forge postgresql -y

# 手动安装 RabbitMQ
conda install -c conda-forge rabbitmq-server -y
```

### Q4: 数据库连接失败

**解决方案：**
```bash
# 检查 PostgreSQL 是否运行
pg_isready -h 127.0.0.1 -p 5432

# 测试手动连接
PGPASSWORD=123 psql -h 127.0.0.1 -p 5432 -U aiida_user -d aiida_db
```

## 预期输出示例

### 成功的 PostgreSQL 设置

```
╔══════════════════════════════════════════════════════════════╗
║  Step 1/5: PostgreSQL Validation
╚══════════════════════════════════════════════════════════════╝

Checking PostgreSQL installation...
  [OK]   PostgreSQL client installed: 14.22

Checking PostgreSQL server...
  [OK]   PostgreSQL server is running on 127.0.0.1:5432

Testing database connection...
  [OK]   Connected to PostgreSQL server
  [OK]   User 'aiida_user' already exists
  [OK]   Database 'aiida_db' already exists
  [OK]   Connected to database 'aiida_db' as user 'aiida_user'

──────────────────────────────────────────
Summary:
  [OK]   PostgreSQL client
  [OK]   PostgreSQL server
  [OK]   Database connection
──────────────────────────────────────────

[INFO] PostgreSQL validation passed!
```

### 成功的 RabbitMQ 设置

```
╔══════════════════════════════════════════════════════════════╗
║  Step 2/5: RabbitMQ Validation
╚══════════════════════════════════════════════════════════════╝

Checking RabbitMQ installation...
  [OK]   RabbitMQ installed: 3.8.3

Checking RabbitMQ server...
  [OK]   RabbitMQ server is running on 127.0.0.1:5672

Configuring RabbitMQ user and vhost...
  [OK]   User 'aiida' already exists
  [OK]   Vhost 'aiida' already exists
  [OK]   Permissions set for vhost 'aiida'

──────────────────────────────────────────
Summary:
  [OK]   RabbitMQ client
  [OK]   RabbitMQ server
  [OK]   RabbitMQ configured
──────────────────────────────────────────

[INFO] RabbitMQ validation passed!
```

## 下一步

完成设置后，激活 conda 环境并测试：

```bash
# 激活环境
conda activate aiida

# 检查状态
verdi status
```

## 脚本文件列表

- `setup_aiida_profile.sh` - 主设置脚本
- `scripts/00-setup-conda.sh` - Conda 环境设置
- `scripts/01-validate-postgresql.sh` - PostgreSQL 安装和配置
- `scripts/02-validate-rabbitmq.sh` - RabbitMQ 安装和配置
- `scripts/03-validate-aiida.sh` - AiiDA 验证
- `scripts/04-setup-profile.sh` - AiiDA Profile 设置
- `scripts/common.sh` - 通用函数和工具
- `config.env` - 配置文件
