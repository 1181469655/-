#!/bin/bash
SYSTEM_NGINX_SERVICE="/etc/systemd/system/nginx.service"
DEFAULT_NFINX_CONFIG="/www/data/nginx/nginx/nginx.conf"
# 检查是否提供了版本号作为参数
if [ -z "$1" ]; then
    echo "请提供 Nginx 版本号作为参数，例如：1.28.0"
    exit 1
fi

VERSION=$1
SCRIPT_DIR="/www/script"
cd $SCRIPT_DIR
pwd
if [ -f nginx-${VERSION}.tar.gz ]; then
	ehco "nginx压缩包已存在，跳过下载"
else
	echo "开始下载nginx压缩包"
	wget https://nginx.org/download/nginx-${VERSION}.tar.gz
fi
tar -xvf nginx-${VERSION}.tar.gz
cd /www/script/nginx-${VERSION}
./configure --prefix=/www/server/nginx/--conf-path=/www/data/nginx/nginx/nginx.conf --with-http_ssl_module
make
make install
#配置权限
chown www:www -R /www/server/nginx /www/data/nginx/
chmod 770 -R /www/server/nginx /www/data/nginx/
#修改nginx配置文件
cat > "$DEFAULT_OVERRIDE" << EOF
user www;
worker_processes auto;
pid /www/data/run/nginx.pid;
include modules-enabled/*.conf;
events {
    worker_connections 1024;
}
http {
    log_format main '\$remote_addr - \$remote_user \[\$time_local\] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include mime.types;
    default_type application/octet-stream;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    keepalive_timeout 65;
    include /www/data/nginx/conf/**/*.conf;
}
EOF	
#配置system服务管理
cat > "$SYSTEM_NGINX_SERVICE" << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/www/data/run/nginx.pid
ExecStartPre=/www/server/nginx/sbin/nginx -t
ExecStart=/www/server/nginx/sbin/nginx
ExecReload=/www/server/nginx/sbin/nginx -s reload
ExecStop=/www/server/nginx/sbin/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target

EOF	
echo "nginx安装配置完成"
