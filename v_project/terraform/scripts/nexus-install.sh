#!/bin/bash
set -e

# Log all output to /var/log/user-data.log for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "============================================================"
echo "Starting Nexus 3 Installation (Free Tier Optimized)"
echo "============================================================"

# 1. SETUP 2.5GB SWAP SPACE (Allows Nexus 3 to run within 10GB disk on t3.micro)
if ! grep -q '/swapfile' /etc/fstab; then
    echo "Creating 2.5GB swap file..."
    fallocate -l 2560M /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2560
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# 2. INSTALL JAVA 17 & PREREQUISITES
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openjdk-17-jdk wget curl tar

# 3. DOWNLOAD & EXTRACT NEXUS
mkdir -p /opt/nexus
cd /tmp
NEXUS_URL="https://download.sonatype.com/nexus/3/nexus-unix-x86-64-3.78.0-14.tar.gz"
echo "Downloading Nexus from ${NEXUS_URL}..."
wget -q --show-progress "${NEXUS_URL}" -O nexus.tar.gz

tar -xzf nexus.tar.gz -C /opt/nexus/
rm -f nexus.tar.gz # Delete installer tarball immediately to save disk space

NEXUS_DIR=$(ls -d /opt/nexus/nexus-3* | head -n 1)

# 4. TUNE JVM MEMORY FOR T3.MICRO (Crucial to prevent Out-Of-Memory)
cat <<EOT > ${NEXUS_DIR}/bin/nexus.vmoptions
-Xms256m
-Xmx512m
-XX:MaxDirectMemorySize=512m
-Djava.net.preferIPv4Stack=true
-Dkaraf.home=.
-Dkaraf.base=.
-Dkaraf.etc=etc/karaf
-Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
-Dkaraf.data=../sonatype-work/nexus3
-Dkaraf.log=../sonatype-work/nexus3/log
-Djava.io.tmpdir=../sonatype-work/nexus3/tmp
EOT

# 5. CREATE DEDICATED NEXUS USER & SET PERMISSIONS
id -u nexus &>/dev/null || useradd -c "Nexus Service User" -d /opt/nexus -m -s /bin/bash nexus
echo 'run_as_user="nexus"' > ${NEXUS_DIR}/bin/nexus.rc
chown -R nexus:nexus /opt/nexus
mkdir -p /opt/nexus/sonatype-work
chown -R nexus:nexus /opt/nexus/sonatype-work

# 6. SETUP SYSTEMD SERVICE
cat <<EOT > /etc/systemd/system/nexus.service
[Unit]
Description=Sonatype Nexus Service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=${NEXUS_DIR}/bin/nexus start
ExecStop=${NEXUS_DIR}/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable nexus.service
systemctl start nexus.service

echo "============================================================"
echo "Nexus 3 Installation Completed & Service Started!"
echo "============================================================"
