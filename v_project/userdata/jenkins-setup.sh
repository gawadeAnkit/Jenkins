#!/bin/bash
sudo apt update -y
 
# Jenkins requires Java 21+
sudo apt install openjdk-21-jdk -y
 
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
 
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
/etc/apt/sources.list.d/jenkins.list > /dev/null
 
sudo apt-get update -y
 
sudo apt-get install jenkins -y
sudo systemctl enable --now jenkins
