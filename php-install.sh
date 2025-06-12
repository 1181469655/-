#!/bin/bash

# 设置 PHP 安装版本、安装路径等变量
PHP_VERSION=$1
VERSION_DIR=$(echo $PHP_VERSION | sed 's/[^0-9]//g' | cut -c1-2)  # 只保留 PHP 版本的前两位，例如：8.4
INSTALL_DIR="/www/server/php/$VERSION_DIR"
CONFIG_PATH="/www/server/php/$INSTALL_DIR/etc"
PHP_FPM_CONF="$INSTALL_DIR/php-fpm.conf"
touch ${PHP_FPM_CONF}
USER=$(whoami)
SYMLINK="/usr/bin/php"
TARGET="/www/server/php/84/bin/php"
PHP_FPM_SYSTEM="/etc/systemd/system/php${VERSION_DIR}-fpm.service"
mkdir -p /www/script/php
# 检查是否提供了 PHP 版本

if [ -z "$PHP_VERSION" ]; then
  echo "错误：请提供 PHP 版本 (例如：8.4.6)"
  exit 1
fi

# 下载并解压指定版本的 PHP（当前目录）
echo "下载 PHP $PHP_VERSION ..."
wget https://www.php.net/distributions/php-$PHP_VERSION.tar.xz
tar -xvf php-$PHP_VERSION.tar.xz
cd php-$PHP_VERSION

# 配置 PHP 编译选项
echo "配置 PHP 编译..."
./configure --prefix=$INSTALL_DIR \
            --with-config-file-path=$CONFIG_PATH \
            --enable-fpm \
            --with-fpm-user=$USER \
            --with-fpm-group=$USER \
            --enable-mbstring \
            --enable-sqlite3 \
            --enable-pdo \
            --with-pdo-sqlite \
            --enable-zip \
			--enable-pear \
            --enable-soap \
            --with-curl \
            --with-openssl \
            --with-zlib \
            --with-xsl \
            --with-mysqli \
            --with-bz2 \
            --enable-bcmath \
            --enable-sockets \
            --enable-sysvsem \
            --enable-shmop \
            --enable-sigchild

			

# 检查是否有 Makefile 生成，如果没有就退出
if [ ! -f "Makefile" ]; then
    echo "错误：配置过程中未生成 Makefile，检查配置过程中的错误。"
    exit 1
fi

# 编译并安装 PHP
echo "编译并安装 PHP $PHP_VERSION ..."
make -j"$(nproc)"
sudo make install

# 配置 PHP-FPM

# 检查并创建 php-fpm.d 目录（如果不存在）
echo "检查并创建 php-fpm.d 目录 ..."
if [ ! -d "/www/data/php/php-fpm-pool" ]; then
    echo "目录 /www/data/php/php-fpm-pool 不存在，正在创建 ..."
    sudo mkdir -p /www/data/php/php-fpm-pool
fi

#创建php-fpm配置目录
mkdir -p /www/data/php/php-fpm-pool/$VERSION_DIR
# 创建软链接，将 php-fpm.d 映射到 /www/data/php/php-fpm-pool
echo "创建 php-fpm.d 软链接 ..."
rm -rf $INSTALL_DIR/etc/php-fpm.d
ln -s /www/data/php/php-fpm-pool/$VERSION_DIR/ $INSTALL_DIR/etc/php-fpm.d


#写入php-fpm.conf配置
cat > "$PHP_FPM_CONF" << EOF
[global]
pid = /www/data/run/php-${VERSION_DIR}-fpm.pid
include=/www/server/php/${VERSION_DIR}/etc/php-fpm.d/*.conf
EOF

#设置默认版本php
# 检查符号链接是否存在
if [ -L "$SYMLINK" ]; then
    # 获取当前符号链接指向的目标路径
    CURRENT_PHP_PATH=$(readlink -f "$SYMLINK")
    
    # 获取当前 PHP 版本
    CURRENT_PHP_VERSION=$($CURRENT_PHP_PATH -v | head -n 1 | awk '{print $2}')

    # 检查当前版本是否为 PHP 8.4
    if [[ "$CURRENT_PHP_VERSION" == "8.4"* ]]; then
        echo "当前PHP版本是 $CURRENT_PHP_VERSION，无需更新。"
    else
        echo "当前PHP版本是$CURRENT_PHP_VERSION，不是 PHP 8.4，正在更新..."

        # 删除旧的符号链接
        sudo rm -rf "$SYMLINK"

        # 创建新的符号链接
        sudo ln -s "$TARGET" "$SYMLINK"

        echo "默认PHP已更新为PHP8.4"
		chmod +x $SYMLINK
        php -v
    fi
else
    echo "默认PHP不存在，开始设置默认PHP"

    # 创建新的符号链接
    sudo ln -s "$TARGET" "$SYMLINK"
    echo "默认PHP已设置为PHP8.4"
	chmod +x $SYMLINK
    php -v
fi


#设置system管理
cat > "$PHP_FPM_SYSTEM" << EOF
[Unit]
Description=PHP8 FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/www/data/run/php-${VERSION_DIR}-fpm.pid
ExecStart=/www/server/php/${VERSION_DIR}/sbin/php-fpm --fpm-config /www/server/php/${VERSION_DIR}/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
echo "PHP $PHP_VERSION 安装完成！"
#启动php-fpm并设置开机自启
echo "启动 PHP-FPM ..."
systemctl daemon-reload 
systemctl start php${VERSION_DIR}-fpm.service
systemctl enable php${VERSION_DIR}-fpm.service
ps -axu | grep php-fpm
echo "PHP-FPM启动完成"

#保留源码包
cd ..
mv php-$PHP_VERSION /www/script/php/$VERSION_DIR
cp /www/script/php/$VERSION_DIR/php.ini-production $CONFIG_PATH/php.ini
chown www:www -R $INSTALL_DIR 
chmod 770 $INSTALL_DIR 
echo "安装过程已完成并清理临时文件！"
