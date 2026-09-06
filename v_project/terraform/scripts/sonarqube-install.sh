#!/bin/bash
set -e

# Log all output to /var/log/user-data.log for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "============================================================"
echo "Starting SonarQube Code Quality Server Installation"
echo "============================================================"

# 1. SETUP SWAP SPACE
if ! grep -q '/swapfile' /etc/fstab; then
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# 2. CONFIGURE KERNEL LIMITS FOR ELASTICSEARCH & SONARQUBE
cat <<EOT >> /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
EOT
sysctl -p

cat <<EOT >> /etc/security/limits.conf
sonar   -   nofile   65536
sonar   -   nproc    4096
EOT

# 3. INSTALL JAVA 21
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openjdk-21-jdk curl wget zip unzip net-tools

# 4. INSTALL & CONFIGURE POSTGRESQL
apt-get install -y postgresql postgresql-contrib
systemctl enable --now postgresql.service

sudo -i -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'admin123';" || true
sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;" || true
sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;" || true

systemctl restart postgresql

# 5. DOWNLOAD & EXTRACT SONARQUBE
mkdir -p /sonarqube
cd /sonarqube
SONAR_ZIP_URL="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-26.4.0.121862.zip"
echo "Downloading SonarQube from ${SONAR_ZIP_URL}..."
wget -q --show-progress "${SONAR_ZIP_URL}" -O sonarqube.zip

unzip -q sonarqube.zip -d /opt/
rm -f sonarqube.zip
EXT_DIR=$(unzip -l /opt/sonarqube.zip 2>/dev/null || ls -d /opt/sonarqube-* | head -n 1)
if [ -d "${EXT_DIR}" ] && [ ! -d "/opt/sonarqube" ]; then
    mv "${EXT_DIR}" /opt/sonarqube
fi

# Create dedicated sonar user
id -u sonar &>/dev/null || useradd -c "SonarQube - User" -d /opt/sonarqube/ -m -s /bin/bash sonar
chown -R sonar:sonar /opt/sonarqube
chmod 1777 /tmp

# 6. CONFIGURE SONAR.PROPERTIES
cat <<EOT > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server -Xms256m -Xmx512m
sonar.search.javaOpts=-Xms256m -Xmx256m
sonar.log.level=INFO
sonar.path.logs=logs
EOT

# 7. CREATE SYSTEMD SERVICE
cat <<EOT > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable sonarqube.service
systemctl start sonarqube.service

echo "============================================================"
echo "SonarQube Installation Completed & Service Started!"
echo "============================================================"
