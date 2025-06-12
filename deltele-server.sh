#!/bin/bash

# 启用严格模式（遇错即停）
set -e

# 检查是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 请以 root 权限运行此脚本。"
    exit 1
fi

# 检查是否提供了用户名参数
if [ -z "$1" ]; then
    echo "❌ 请提供要删除的用户名作为参数。"
    exit 1
fi

USER="$1"

# MySQL 管理员信息
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD=$(cat /www/data/mysql/mysql_temp_password.txt)

# 删除 FTP 用户
if /www/server/ftp/bin/pure-pw userdel "$USER" > /dev/null 2>&1; then
    /www/server/ftp/bin/pure-pw mkdb > /dev/null 2>&1 || echo "⚠️ FTP 用户数据库更新失败。"
else
    echo "⚠️ FTP 用户 $USER 不存在或删除失败。"
fi

# 删除用户
if id "$USER" &>/dev/null; then
    userdel "$USER" || echo "⚠️ 删除用户 $USER 失败。"
else
    echo "ℹ️ 用户 $USER 不存在，跳过 userdel。"
fi

# 删除组
if getent group "$USER" > /dev/null; then
    groupdel "$USER" || echo "⚠️ 删除组 $USER 失败，可能是主组。"
fi

# 删除相关目录
for dir in "/home/${USER}" "/www/data/nginx/conf/${USER}" "/www/data/php/${USER}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "🗑️ 删除目录 $dir"
    fi
done

# 删除 MySQL 用户与数据库
/www/server/mysql/bin/mysql -u"$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" <<EOF
-- 删除数据库
DROP DATABASE IF EXISTS \`$USER\`;

-- 删除用户
DROP USER IF EXISTS '$USER'@'%';

-- 刷新权限
FLUSH PRIVILEGES;
EOF

echo "✅ 用户 $USER 和数据库 $USER 已彻底删除。"
