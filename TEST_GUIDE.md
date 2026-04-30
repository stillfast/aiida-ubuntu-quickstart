首先新建 `conda` 虚拟环境：（`aiida-core.services`）应该默认配置好了 rabbitMQ 和 PostgreSQL，如果没有请自行下载。
```
conda create -n aiida python=3.10 -c conda-forge aiida-core
conda activate aiida
```
下载 aiida 与各个软件的接口：
```
pip install aiida-vasp
```
安装 PostgreSQL：
```
conda install -c conda-forge postgresql
```
安装 RabbitMQ：
```
conda install conda-forge::rabbitmq-server==3.8.3
```
新建数据库的文件夹 （最好放在用户文件夹下）：
```
mkdir mylocal_db
initdb -D mylocal_db
```
修改数据库 ：
```shell
# pg_ctl.exe status 查看是否启动
pg_ctl -D mylocal_db -o "-p 5433" -l logfile start
psql -h localhost -p 5433 -d postgres
# 在 psql 提示符下执行：
CREATE USER aiida_user WITH PASSWORD '123';
CREATE DATABASE aiida_db OWNER aiida_user;
ALTER DATABASE aiida_db SET timezone TO 'Asia/Shanghai';
GRANT ALL PRIVILEGES ON DATABASE aiida_db TO aiida_user;
# 时区可以设置为'Etc/GMT-8'
\l  -- 查看数据库列表
\du  -- 查看用户列表
\q   -- 退出
```
对应的 profile 是：
```shell
verdi profile setup core.psql_dos -n \
  --profile-name aiida \
  --set-as-default \
  --email liguozhou24@gscaep.ac.cn \
  --first-name Guozhou \
  --last-name Li \
  --institution "Graduate school of CAEP" \
  --use-rabbitmq \
  --database-username aiida_user \
  --database-password 123 \
  --database-name aiida_db \
  --database-engine postgresql_psycopg \
  --database-hostname 127.0.0.1 \
  --database-port 5433 \
  --repository-uri "file:///C:/Users/lee/Documents/trae_projects/aiida/data/aiida_profile/aiida0324"

```