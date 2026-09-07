output "instance_id" {
  description = "The EC2 Instance ID of the Jenkins Server"
  value       = aws_instance.jenkins_server.id
}

output "jenkins_public_ip" {
  description = "Public IP address of the Jenkins Server"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_url" {
  description = "Web address to access the Jenkins dashboard"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "ssh_connection_command" {
  description = "Command to SSH into your Jenkins server"
  value       = "ssh -i jenkins-key.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
}

output "get_initial_admin_password_command" {
  description = "Command to retrieve the initial Jenkins admin unlock password"
  value       = "ssh -i jenkins-key.pem ubuntu@${aws_instance.jenkins_server.public_ip} cat /home/ubuntu/jenkins_initial_admin_password.txt"
}

output "vprofile_alb_dns_name" {
  description = "Permanent DNS Name of the Application Load Balancer"
  value       = aws_lb.vprofile_alb.dns_name
}

output "vprofile_app_url" {
  description = "Permanent live URL for the VProfile Application (Port 80)"
  value       = "http://${aws_lb.vprofile_alb.dns_name}"
}



