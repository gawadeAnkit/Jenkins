# ------------------------------------------------------------------------------
# 1. DATA SOURCES: VPC, Subnet, AMI, & Public IP
# ------------------------------------------------------------------------------

# Fetch the Default VPC (100% Free - avoids expensive NAT Gateways)
data "aws_vpc" "default" {
  default = true
}

# Fetch subnets within the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  }
}

# Automatically query the latest official Ubuntu 22.04 LTS Free Tier AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Automatically detect your workstation's public IP address
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# ------------------------------------------------------------------------------
# 2. KEY PAIR (Auto-Generated - No Manual Creation Required)
# ------------------------------------------------------------------------------

# Generates a secure RSA private key
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Saves the private key locally as jenkins-key.pem for SSH access
resource "local_file" "private_key_pem" {
  content         = tls_private_key.jenkins_key.private_key_pem
  filename        = "${path.module}/jenkins-key.pem"
  file_permission = "0400"
}

# Registers the public key with AWS EC2
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh

  tags = {
    Name    = "jenkins-key"
    Project = "vprofile"
  }
}

# ------------------------------------------------------------------------------
# 3. SECURITY GROUP FOR JENKINS
# ------------------------------------------------------------------------------
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-server-sg"
  description = "Security group for Jenkins server (Port 22 & 8080)"
  vpc_id      = data.aws_vpc.default.id

  # SSH access restricted to your detected public IP for security
  ingress {
    description = "SSH from your public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  # Jenkins Web UI on port 8080
  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound access to download packages, plugins, and git repos
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "jenkins-server-sg"
    Project = "vprofile"
  }
}

# ------------------------------------------------------------------------------
# 4. EC2 INSTANCE: "Jenkins server" (100% Free Tier Eligible)
# ------------------------------------------------------------------------------
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type # t2.micro (750 hours/month free)
  key_name                    = aws_key_pair.jenkins_key.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  # Bootstrap script: installs Java 17, Jenkins LTS, Git, Maven + sets up 3GB Swap
  user_data = file("${path.module}/scripts/jenkins-install.sh")

  # 25 GB gp3 volume (Safely within AWS 30 GB Free Tier EBS limit)
  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "${var.instance_name}-root-disk"
    }
  }

  tags = {
    Name        = var.instance_name # Tagged as "Jenkins server"
    Project     = "vprofile"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}
