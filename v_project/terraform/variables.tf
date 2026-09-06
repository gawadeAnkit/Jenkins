variable "aws_region" {
  description = "AWS Region to deploy resources into (defaults to your configured us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag for the Jenkins EC2 instance"
  type        = string
  default     = "Jenkins server"
}

variable "instance_type" {
  description = "EC2 Instance type (t2.micro is 100% Free Tier eligible - 750 hrs/month)"
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Root EBS volume size in GB (Free tier includes up to 30 GB total across account)"
  type        = number
  default     = 8
}
