#!/bin/bash
PURE_FTPD_CONFIG="/www/data/ftp/pure-ftpd.conf"
SYSTEM_PURE_FTPD_CONFIG="/etc/systemd/system/pure-ftpd.service"
rm -rf pure-ftpd-1.0.52.tar.gz
wget https://download.pureftpd.org/pub/pure-ftpd/releases/pure-ftpd-1.0.52.tar.gz   
tar -xvf pure-ftpd-1.0.52.tar.gz
cd pure-ftpd-1.0.52

sudo apt install build-essential libssl-dev zlib1g-dev libpam0g-dev libldap2-dev


./configure --prefix=/www/server/ftp --sysconfdir=/www/data/ftp --with-puredb --with-nonroot
make clean
make
make install
cat > "$PURE_FTPD_CONFIG" << EOF
ChrootEveryone               yes
BrokenClientsCompatibility   no
MaxClientsNumber             50
Daemonize                    yes
MaxClientsPerIP              8
VerboseLog                   no
DisplayDotFiles              yes
AnonymousOnly                no
NoAnonymous                  yes
SyslogFacility               ftp
DontResolve                  yes
MaxIdleTime                  15
PureDB                       /www/data/ftp/pureftpd.pdb
LimitRecursion               10000 8
AnonymousCanCreateDirs       no
MaxLoad                      4
AntiWarez                    yes
Umask                        133:022
MinUID                       100
AllowUserFXP                 no
AllowAnonymousFXP            no
ProhibitDotFilesWrite        no
ProhibitDotFilesRead         no
AutoRename                   no
AnonymousCantUpload          no
PIDFile                      /www/data/run/pure-ftpd.pid
MaxDiskUsage                   99
CustomerProof                yes
EOF
cat > "$SYSTEM_PURE_FTPD_CONFIG" << EOF
[Unit]
Description=Pure-FTPd FTP server
After=network.target

[Service]
Type=forking
User=www
Group=www
ExecStart=/www/server/ftp/sbin/pure-ftpd /www/data/ftp/pure-ftpd.conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target

EOF

echo "pure-ftp配置安装完成"
