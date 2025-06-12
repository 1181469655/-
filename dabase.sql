CREATE TABLE IF NOT EXISTS "serverlist" (
	"id" INTEGER NOT NULL UNIQUE,
	-- 虚拟机编号
	"host_id" VARCHAR UNIQUE,
	-- web用户名
	"user" VARCHAR NOT NULL UNIQUE,
	-- web密码
	"passwd" VARCHAR NOT NULL,
	-- 家目录
	"home_path" TEXT NOT NULL,
	-- sql空间
	"sqlmax" INTEGER NOT NULL DEFAULT 300,
	-- web空间
	"webmax" INTEGER NOT NULL DEFAULT 300,
	-- 带宽限速
	"network" INTEGER NOT NULL,
	-- 域名列表
	"domain_name" TEXT DEFAULT '[""]',
	-- api密钥
	"api_key" TEXT NOT NULL UNIQUE,
	-- 伪静态
	"pseudo_static" TEXT,
	-- PHP版本
	"php_version" TEXT NOT NULL DEFAULT '84',
	-- 运行目录
	"web_path" TEXT NOT NULL,
	-- 默认文件
	"default_file" TEXT NOT NULL DEFAULT '["index.php","index.html"]',
	-- 禁用函数
	"disabled_functions" TEXT NOT NULL DEFAULT '[""]',
	-- 禁用扩展
	"disable_extensions" TEXT NOT NULL DEFAULT '[""]',
	-- ftp用户名
	"ftp_user" TEXT NOT NULL UNIQUE,
	-- ftp密码
	"ftp_passwd" TEXT NOT NULL,
	-- sql用户名
	"sql_user" TEXT NOT NULL,
	-- sql密码
	"sql_passwd" TEXT NOT NULL,
	-- 网站访问密码,空白则是关闭
	"nginx_passwd_access" TEXT,
	-- ssl是否开启0关闭1开启
	"ssl_switch" TEXT DEFAULT '0',
	-- 虚拟主机状态0关闭1开启
	"status" TEXT DEFAULT '1',
	PRIMARY KEY("id")
);

CREATE INDEX IF NOT EXISTS "[object Object]"
ON "serverlist" ("undefined");