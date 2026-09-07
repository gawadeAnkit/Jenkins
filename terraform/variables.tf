variable "aws_region" {
  description = "AWS Region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag for the Jenkins EC2 instance"
  type        = string
  default     = "Jenkins server"
}

variable "instance_type" {
  description = "EC2 Instance type for CI/CD servers"
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 10
}

