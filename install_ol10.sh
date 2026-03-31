#!/bin/bash
#--------------------------------------------------------------------
# Script to Install Prometheus Server on Oracle Linux 10
# Tested on Oracle Linux 10.1
# Developed by Mukas Oleksandr in 2026
#--------------------------------------------------------------------
PROMETHEUS_VERSION="3.5.1"
PROMETHEUS_FOLDER_CONFIG="/etc/prometheus"
PROMETHEUS_FOLDER_TSDB="/var/lib/prometheus"
PROMETHEUS_FOLDER_TSDATA="/var/lib/prometheus/data"

# tar,wget has been in Oracle Linux 10.1 in default, its for sure
dnf update -y -q || exit 1
dnf install -y -q tar wget || exit 1
cd /tmp
wget -q --show-progress https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar -xvzf prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
cd prometheus-$PROMETHEUS_VERSION.linux-amd64


mv prometheus /usr/local/bin/
rm -rf /tmp/prometheus-$PROMETHEUS_VERSION.linux-amd64*

mkdir -p $PROMETHEUS_FOLDER_CONFIG
mkdir -p $PROMETHEUS_FOLDER_TSDATA


cat <<EOF> $PROMETHEUS_FOLDER_CONFIG/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name      : "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOF

id prometheus &>/dev/null || useradd -rs /bin/false prometheus
chown prometheus:prometheus /usr/local/bin/prometheus
chown -R prometheus:prometheus $PROMETHEUS_FOLDER_CONFIG
#chown prometheus:prometheus $PROMETHEUS_FOLDER_CONFIG/prometheus.yml
chown -R prometheus:prometheus $PROMETHEUS_FOLDER_TSDATA


cat <<EOF> /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/prometheus \
  --config.file       ${PROMETHEUS_FOLDER_CONFIG}/prometheus.yml \
  --storage.tsdb.path ${PROMETHEUS_FOLDER_TSDATA}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

#SElinux setings
restorecon -v /usr/local/bin/prometheus
restorecon -Rv $PROMETHEUS_FOLDER_CONFIG
restorecon -Rv $PROMETHEUS_FOLDER_TSDB

#port 9090 busy - Oracle Cockpit
# Перевіряємо, чи socket активний
if systemctl is-active --quiet cockpit.socket; then
echo "Stopping Cockpit..."
sudo systemctl stop cockpit.socket
sudo systemctl disable cockpit.socket
fi

# Додатково можна зупинити сам сервіс для надійності
if systemctl is-active --quiet cockpit.service; then
sudo systemctl stop cockpit.service
sudo systemctl disable cockpit.service
fi

echo "Cockpit fully disabled."

sleep 2

systemctl start prometheus
systemctl enable prometheus
sleep 2
systemctl status prometheus --no-pager

export PATH=/usr/local/bin:$PATH
prometheus --version
which prometheus
