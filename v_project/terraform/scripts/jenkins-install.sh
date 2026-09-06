#!/bin/bash
set -e

# Redirect all logs to /var/log/user-data.log for easy troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "============================================================"
echo "Starting Free Tier Jenkins Installation (with 3GB Swap)"
echo "============================================================"

# 1. SETUP SWAP SPACE (Dynamically sized to fit volume)
# Essential for t2.micro / t3.micro (1GB RAM) to run Java 17 + Jenkins + Maven without crashing
if ! grep -q '/swapfile' /etc/fstab; then
    FREE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$FREE_DISK_GB" -le 6 ]; then
        SWAP_SIZE="1G"
        SWAP_COUNT=1024
    else
        SWAP_SIZE="2G"
        SWAP_COUNT=2048
    fi
    echo "Allocating ${SWAP_SIZE} swap file (Free disk: ${FREE_DISK_GB}G)..."
    fallocate -l ${SWAP_SIZE} /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=${SWAP_COUNT}
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    echo "Swap allocated successfully. Total available memory:"
    free -h
fi

# 2. UPDATE SYSTEM PACKAGES & INSTALL DEPENDENCIES
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openjdk-17-jdk git maven curl wget gnupg fontconfig unzip

# 3. ADD OFFICIAL JENKINS REPOSITORY KEY & SOURCE
mkdir -p /etc/apt/keyrings
wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

# 4. TUNE JVM MEMORY FOR T2.MICRO (limit heap to 512MB max)
mkdir -p /etc/systemd/system/jenkins.service.d/
cat <<EOF > /etc/systemd/system/jenkins.service.d/override.conf
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xms256m -Xmx512m"
EOF

systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins

# 5. RETRIEVE INITIAL ADMIN PASSWORD
echo "Waiting for Jenkins service to initialize and generate admin password..."
for i in {1..60}; do
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        echo "Admin password generated!"
        break
    fi
    sleep 2
done

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    cp /var/lib/jenkins/secrets/initialAdminPassword /home/ubuntu/jenkins_initial_admin_password.txt
    chmod 644 /home/ubuntu/jenkins_initial_admin_password.txt
    chown ubuntu:ubuntu /home/ubuntu/jenkins_initial_admin_password.txt
fi

echo "============================================================"
echo "Jenkins installation completed successfully!"
echo "============================================================"
