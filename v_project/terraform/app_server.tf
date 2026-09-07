# ==============================================================================
# APP SERVER (TOMCAT) SECURITY GROUP
# ==============================================================================
resource "aws_security_group" "app_server_sg" {
  name        = "app-server-sg"
  description = "Security group for VProfile Tomcat App Server (Ports 22 & 8080)"
  vpc_id      = data.aws_vpc.default.id

  # SSH access from your workstation's detected IP
  ingress {
    description = "SSH from your public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  # SSH access from Jenkins server for Ansible orchestration
  ingress {
    description     = "SSH from Jenkins server"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
  }

  # Tomcat Web Application port 8080
  ingress {
    description = "Tomcat Web UI and VProfile Webapp"
    from_port   = 8080
    to_port     = 8080
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
    Name    = "app-server-sg"
    Project = "vprofile"
  }
}

# ==============================================================================
# APP SERVER EC2 INSTANCE (Tomcat Runtime Host)
# ==============================================================================
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.jenkins_key.key_name
  vpc_security_group_ids      = [aws_security_group.app_server_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  # 8 GB minimal gp3 volume
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "App server-root-disk"
    }
  }

  tags = {
    Name        = "App server"
    Project     = "vprofile"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# OUTPUTS FOR APP SERVER
# ==============================================================================
output "app_server_public_ip" {
  description = "Public IP of the Tomcat App Server"
  value       = aws_instance.app_server.public_ip
}

output "app_server_url" {
  description = "Tomcat Web Application URL"
  value       = "http://${aws_instance.app_server.public_ip}:8080"
}

output "app_server_ssh_command" {
  description = "Command to SSH into your App Server"
  value       = "ssh -i jenkins-key.pem ubuntu@${aws_instance.app_server.public_ip}"
}
