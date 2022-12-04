variable "region" {
  type    = string
  default = "us-west-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.123.0.0/16"
}

variable "access_ip" {
  type    = string
  default = "0.0.0.0/0"
}

variable "cloud9_ip" {
  type    = string
  default = "54.176.163.159/32"
}

variable "public_cidrs" {
  type    = list(string)
  default = ["10.123.1.0/24", "10.123.3.0/24"]
}

variable "private_cidrs" {
  type    = list(string)
  default = ["10.123.2.0/24", "10.123.4.0/24"]
}

variable "subnet2_cidr" {
  type    = string
  default = "10.123.6.0/24"
}

variable "subnet3_cidr" {
  type    = string
  default = "10.123.8.0/24"
}

variable "main_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "main_vol_size" {
  type    = number
  default = 8
}

variable "main_instance_count" {
  type    = number
  default = 1
}

variable "key_name" {
  type = string
}

variable "public_key_path" {
  type = string
}
variable "private_key_path" {
  type = string
}

variable "allocation_id" {
  type = string
}

variable "main_domain_name" {
  type = string
}

variable "letsencrypt_email" {
  type = string
}

variable "db_name" {
  description = "RDS database name"
  default     = "srw_db"
}

variable "db_user" {
  description = "RDS root username"
  # sensitive   = true
  default = "wordpress_user"
}

variable "db_password" {
  description = "RDS root user password"
  # sensitive   = true
}

variable "github_token" {
  description = "Github token to get latest archive. Visit https://github.com/settings/tokens to get new token"
  # sensitive   = true  
}

variable "github_user" {
  type        = string
  description = "Github repo ex: octocat"
}

variable "github_repo" {
  type        = string
  description = "Github repo ex: Spoon-Knife"
}






