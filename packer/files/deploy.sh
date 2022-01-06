#!/bin/bash
apt-get update
apt-get install -y git
mkdir /var/run/my-reddit-app && mkdir /opt/my-reddit-app
git clone -b monolith https://github.com/express42/reddit.git /opt/my-reddit-app
cd /opt/my-reddit-app
bundle install

cat > /etc/systemd/system/reddit-app.service << EOF
[Unit]
Description=My Reddit App
After=network.target
After=mongod.service

[Service]
Type=simple
PIDFile=/var/run/my-reddit-app/my-reddit.pid
WorkingDirectory=/opt/my-reddit-app

ExecStart=/usr/local/bin/puma

[Install]
WantedBy=multi-user.target
EOF

systemctl enable reddit-app.service
systemctl start reddit-app.service
