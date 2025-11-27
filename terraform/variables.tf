# Variables
variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "vprofile-app"
}

variable "db_name" {
  default = "accounts"
}

variable "db_username" {
  default = "appuser"
}

variable "db_password" {
  sensitive = true
}

variable "rabbitmq_username" {
  default = "test"
}

variable "rabbitmq_password" {
  sensitive = true
}

variable "my_ip" {
  description = "Your IP address for SSH access (format: x.x.x.x/32)"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}
