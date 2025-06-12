#!/bin/bash
# 定义 MySQL 相关路径和用户
MYSQL_BIN="/www/server/mysql/bin/mysqld"
BASEDIR="/www/server/mysql"
DATADIR="/www/data/mysql/db"
USER="mysql"
MYSQL_SYSTEM_CONFIG="/etc/systemd/system/mysql.service"
MYSQL_CONFIG_DIR="/www/data/mysql/etc"
MYSQL_CONFIG_CNF="/www/data/mysql/etc/my.cnf"
MYSQL_ROOT_USER="root"
# 定义存储临时密码的文件路径
PASSWORD_FILE="/www/data/mysql/mysql_temp_password.txt"
#手动编译安装 OpenSSL 1.1（解决兼容性问题）
wget https://www.openssl.org/source/openssl-1.1.1t.tar.gz
tar -zxvf openssl-1.1.1t.tar.gz
cd openssl-1.1.1t
./config --prefix=/www/server/package/openssl
make -j$(nproc)
sudo make install
#安装MySQL
wget https://downloads.mysql.com/archives/get/p/23/file/mysql-5.7.43.tar.gz
tar -xvf mysql-5.7.43.tar.gz
cd mysql-5.7.43
cmake . \
-DCMAKE_INSTALL_PREFIX=/www/server/mysql \
-DMYSQL_DATADIR=/www/data/mysql/db \
-DSYSCONFDIR=/www/data/mysql/etc \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_MEMORY_STORAGE_ENGINE=1 \
-DWITH_READLINE=1 \
-DMYSQL_UNIX_ADDR=/www/data/mysql/mysql.sock \
-DMYSQL_TCP_PORT=3306 \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8mb4 \
-DDEFAULT_COLLATION=utf8mb4_general_ci \
-DDOWNLOAD_BOOST=1 \
-DWITH_BOOST=/www/server/mysql/boost \
-DWITH_SSL=/www/server/package/openssl \
-DOPENSSL_INCLUDE_DIR=/www/server/package/openssl/include \
-DOPENSSL_LIBRARIES="/www/server/package/openssl/lib/libssl.so;/www/server/package/openssl/lib/libcrypto.so"
make -j$(nproc)
make install
#配置用户
groupadd mysql
useradd -r -g mysql -s /bin/false mysql
#附加群组配置权限
usermod -a -G www mysql
#初始化数据库

# 清空数据目录（确保目录为空）
echo "正在清空数据目录..."
sudo rm -rf "$DATADIR"/*

# 初始化 MySQL 数据库
echo "正在初始化 MySQL 数据库..."
INIT_OUTPUT=$($MYSQL_BIN --initialize --user=$USER --basedir=$BASEDIR --datadir=$DATADIR 2>&1)

# 检查初始化是否成功
if [ $? -ne 0 ]; then
    echo "初始化失败！"
    echo "$INIT_OUTPUT"
    exit 1
fi

# 提取临时密码
TEMP_PASSWORD=$(echo "$INIT_OUTPUT" | grep 'A temporary password is generated for root@localhost:' | awk '{print $NF}')

# 检查是否成功提取到临时密码
if [ -n "$TEMP_PASSWORD" ]; then
    echo "临时密码提取成功: $TEMP_PASSWORD"
    # 将临时密码保存到文件中
    echo "$TEMP_PASSWORD" > "$PASSWORD_FILE"
    echo "临时密码已保存到 $PASSWORD_FILE"
else
    echo "未能提取到临时密码，请检查初始化输出。"
    echo "$INIT_OUTPUT"
    exit 1
fi
#写入MySQL启动配置文件
mkdir ${MYSQL_CONFIG_DIR}

#设置MySQL配置文件
cat > "$MYSQL_CONFIG_CNF" << EOF
[client]
port		= 3306
socket		= /www/data/run/mysql.sock

[mysqld]
port		= 3306
default-time-zone = '+08:00'
socket		= /www/data/run/mysql.sock
datadir = /www/data/mysql/db
default_storage_engine = InnoDB
performance_schema_max_table_instances = 200
skip-external-locking
key_buffer_size = 64M
max_allowed_packet = 16M
table_open_cache = 256
sort_buffer_size = 4M
net_buffer_length = 8K
read_buffer_size = 4M
read_rnd_buffer_size = 512K
thread_cache_size = 32
query_cache_size = 0
tmp_table_size = 32M
sql-mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES,NO_AUTO_CREATE_USER
explicit_defaults_for_timestamp = true
skip-name-resolve
max_connections = 200
max_connect_errors = 100
open_files_limit = 10000
log-bin=mysql-bin
binlog_format=row
server-id = 1
expire_logs_days = 15
slow_query_log=1
slow-query-log-file=/www/log/mysql/mysql-slow.log
long_query_time=2
log_queries_not_using_indexes=on
early-plugin-load = ""
innodb_data_home_dir = /www/data/mysql/db
innodb_data_file_path = ibdata1:12M:autoextend
innodb_log_group_home_dir = /www/log/mysql/InnoDB
innodb_buffer_pool_size = 256M
innodb_log_file_size = 128M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50
innodb_max_dirty_pages_pct = 75
innodb_read_io_threads = 4
innodb_write_io_threads = 4

[mysqldump]
quick
max_allowed_packet = 32M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 64M
sort_buffer_size = 4M
read_buffer = 4M
write_buffer = 4M

[mysqlhotcopy]
interactive-timeout
EOF	


#设置MySQL system管理
cat > "$MYSQL_SYSTEM_CONFIG" << EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
User=mysql
Group=mysql
ExecStart=/www/server/mysql/bin/mysqld --defaults-file=/www/data/mysql/etc/my.cnf
ExecReload=/www/server/mysql/bin/mysqladmin reload
ExecStop=/www/server/mysql/bin/mysqladmin shutdown
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
MYSQL_ROOT_PASSWORD=$(cat /www/data/mysql/mysql_temp_password.txt)
systemctl start mysql.service 
/www/server/mysql/bin/mysql -u$MYSQL_ROOT_USER -p$MYSQL_ROOT_PASSWORD -e "
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
"
systemctl stop mysql.service 
echo mysql安装配置完成