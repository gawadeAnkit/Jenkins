# ==============================================================================
# SONARQUBE SECURITY GROUP
# ==============================================================================
resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube-server-sg"
  description = "Security group for SonarQube Server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH administrative access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  ingress {
    description = "SonarQube Web UI & Scanner API"
    from_port   = 9000
    to_port     = 9000
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
    Name    = "sonarqube-server-sg"
    Project = "vprofile"
  }
}

# ==============================================================================
# SONARQUBE EC2 INSTANCE
# ==============================================================================
resource "aws_instance" "sonarqube_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.jenkins_key.key_name
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "SonarQube server-root-disk"
    }
  }

  user_data = file("${path.module}/scripts/sonarqube-install.sh")

  tags = {
    Name        = "SonarQube server"
    Project     = "vprofile"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# OUTPUTS FOR SONARQUBE
# ==============================================================================
output "sonarqube_public_ip" {
  description = "Public IP of the SonarQube server"
  value       = aws_instance.sonarqube_server.public_ip
}

output "sonarqube_url" {
  description = "SonarQube Web UI URL"
  value       = "http://${aws_instance.sonarqube_server.public_ip}:9000"
}

output "sonarqube_ssh_command" {
  description = "Command to SSH into your SonarQube server"
  value       = "ssh -i jenkins-key.pem ubuntu@${aws_instance.sonarqube_server.public_ip}"
}
