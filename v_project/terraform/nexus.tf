# ==============================================================================
# NEXUS SECURITY GROUP
# ==============================================================================
resource "aws_security_group" "nexus_sg" {
  name        = "nexus-server-sg"
  description = "Security group for Nexus Repository Manager (Ports 22 & 8081 only)"
  vpc_id      = data.aws_vpc.default.id

  # SSH access restricted to your detected public IP
  ingress {
    description = "SSH from your public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  # Nexus Web UI & Artifact Upload
  ingress {
    description = "Nexus Web Dashboard and Repository API"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "nexus-server-sg"
    Project = "vprofile"
  }
}

# ==============================================================================
# NEXUS EC2 INSTANCE (Strict Minimal Free Tier Setup)
# ==============================================================================
resource "aws_instance" "nexus_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type # t3.micro (Free Tier)
  key_name                    = aws_key_pair.jenkins_key.key_name
  vpc_security_group_ids      = [aws_security_group.nexus_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  # 10 GB minimal volume (Jenkins 8GB + Sonar 10GB + Nexus 10GB = 28GB, safely under 30GB limit)
  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "Nexus server-root-disk"
    }
  }

  user_data = file("${path.module}/scripts/nexus-install.sh")

  tags = {
    Name        = "Nexus server"
    Project     = "vprofile"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# OUTPUTS FOR NEXUS
# ==============================================================================
output "nexus_public_ip" {
  description = "Public IP of the Nexus server"
  value       = aws_instance.nexus_server.public_ip
}

output "nexus_url" {
  description = "Nexus Web UI URL"
  value       = "http://${aws_instance.nexus_server.public_ip}:8081"
}

output "nexus_ssh_command" {
  description = "Command to SSH into your Nexus server"
  value       = "ssh -i jenkins-key.pem ubuntu@${aws_instance.nexus_server.public_ip}"
}

output "nexus_get_admin_password_command" {
  description = "Command to retrieve initial Nexus admin password"
  value       = "ssh -i jenkins-key.pem ubuntu@${aws_instance.nexus_server.public_ip} 'sudo cat /opt/nexus/sonatype-work/nexus3/admin.password'"
}
