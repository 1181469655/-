#!/bin/bash
#创建用户和群组
USER_NAME=$1 #用户名/账号
USER_PASSWORD=$2 #密码（ftp，MySQL同用）
PORT=$3 #站点端口
SERVER_NAME=$4 #站点主机名
NGINX_CONF="/www/data/nginx/conf/$USER_NAME/nginx.conf" #nginx配置文件路径
NGINX_STATIC_CONF="/www/data/nginx/conf/$USER_NAME/config/static.conf" #nginx伪静态配置文件
PHP_FPM_POOL="/www/data/php/php-fpm-pool/84/php-fpm-$USER_NAME-pool.conf"  #php-fpm配置文件
DEFAULT_PAGE="/home/$USER_NAME/www/index.html" #默认网站页面
#MYSQL用户名和密码
# MySQL 管理员用户名
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD=$(cat /www/data/mysql/mysql_temp_password.txt)
useradd -r -m -s /usr/sbin/nologin -d /home/$USER_NAME $USER_NAME
#附加群组
usermod -a -G $USER_NAME www
#创建必要目录
mkdir /www/data/nginx/conf/$USER_NAME  #nginx配置目录
mkdir /www/data/php/$USER_NAME    #创建php配置目录
mkdir -p /www/log/php/$USER_NAME  #创建日志目录
mkdir -p /www/data/nginx/conf/$USER_NAME/config/ #nginx子配置文件
mkdir -p /www/log/nginx/${USER_NAME}/
touch /www/log/nginx/${USER_NAME}/server-access.log /www/log/nginx/${USER_NAME}/server-error.log
#创建家目录下的www目录
mkdir /home/$USER_NAME/www 
#写入nginx配置
cat > "$NGINX_CONF" << EOF
server {
    listen $PORT;
    server_name $SERVER_NAME;
    index index.php index.html;
    root /home/$USER_NAME/www;

    location ~ \.php$ {
        include /www/data/nginx/nginx/fastcgi_params;
        include /www/data/nginx/nginx/fastcgi.conf;
        fastcgi_pass unix:/www/data/php/$USER_NAME/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
	include /www/data/nginx/conf/$USER_NAME/config/static.conf;
	# 禁止访问的文件或目录
    location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md) {
        return 404;
    }
	
    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)\$ {
        expires      30d;
        error_log /dev/null;
        access_log /dev/null;
    }

    location ~ .*\.(js|css)?\$ {
        expires      12h;
        error_log /dev/null;
        access_log /dev/null;
    }
    access_log /www/log/nginx/$USER_NAME/server-access.log;
    error_log /www/log/nginx/$USER_NAME/server-error.log;
}
EOF
#写入nginx伪装静态配置
echo "" > "$NGINX_STATIC_CONF"
#写入php-fpm配置
cat > "$PHP_FPM_POOL" << EOF
[$USER_NAME]
user = $USER_NAME
group = $USER_NAME
listen = /www/data/php/$USER_NAME/php-fpm.sock
listen.owner = $USER_NAME
listen.group = $USER_NAME
listen.mode = 0660
pm = ondemand
pm.max_children = 5
listen.backlog = 256
pm.process_idle_timeout = 20s
access.log = /www/log/php/$USER_NAME/php-access.log
slowlog = /www/log/php/$USER_NAME/php-slow.log
request_slowlog_timeout = 7s
EOF

#默认页面

cat > "$DEFAULT_PAGE" << EOF
hell php nginx
EOF

#配置文件和目录权限
chown $USER_NAME:$USER_NAME -R /home/$USER_NAME
chown $USER_NAME:$USER_NAME -R /www/data/nginx/conf/$USER_NAME
chown $USER_NAME:$USER_NAME -R /www/data/php/$USER_NAME
chown $USER_NAME:$USER_NAME -R /www/log/nginx/${USER_NAME}/
chmod 770 -R /www/log/nginx/${USER_NAME}/
# 重新加载fpm
/www/server/php/84/sbin/php-fpm -c /www/data/php/php-fpm-$USER_NAME-pool.conf -t
if [ $? -eq 0 ]; then
    # 发送reload信号给PHP-FPM主进程
    kill -USR2 $(cat /www/data/run/php-84-fpm.pid)
fi
#重新加载nginx
systemctl reload nginx

www /www/server/ftp/bin/pure-pw useradd $USER_NAME -u $USER_NAME -d /home/$USER_NAME/www <<EOF
$USER_PASSWORD
$USER_PASSWORD
EOF

www /www/server/ftp/bin/pure-pw mkdb

echo "开始配置MySQL数据库"
/www/server/mysql/bin/mysql -u$MYSQL_ROOT_USER -p$MYSQL_ROOT_PASSWORD <<EOF
-- 创建数据库
CREATE DATABASE IF NOT EXISTS \`$USER_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建新用户
CREATE USER IF NOT EXISTS '$USER_NAME'@'%' IDENTIFIED BY '$USER_PASSWORD';

-- 授权用户对数据库的全部权限
GRANT ALL PRIVILEGES ON \`$USER_NAME\`.* TO '$USER_NAME'@'%';

-- 刷新权限
FLUSH PRIVILEGES;
EOF

echo "✅ 数据库 $USER_NAME 和用户 $USER_NAME 已成功创建并授予远程权限。"
