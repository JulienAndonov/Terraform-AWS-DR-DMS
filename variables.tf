variable "source_server" {
  description = "Endpoing of the source server"
  type        = string
}

variable "target_db_username" {
  description = "The username for the target database"
  type        = string
  default     = "thedock"
}

variable "private_key_path" {
  description = "The path to the private key"
  type = string
}

variable "public_key" {
  description = "The public key value"
  type = string
}

variable "ami" {
  description = "AMI for the EC2 image"
  type        = string
  default     = "ami-025d24108be0a614c"
}

variable "target_availability_zone" {
  description = "The target availability zone according to the RDS"
  type = string
}

variable "source_db_username" {
  description = "The username for the source database"
  type        = string
  default     = "thedock"
}

variable "default_subnet_group" {
  description = "The default subnet group name"
  type = string 
}

variable "database_name" {
  description = "The name of the database"
  type        = string
}


variable "target_db_password" {
  description = "The password of the target database user"
  type        = string
}


variable "source_db_password" {
  description = "The password of the source database user"
  type        = string
}


variable "source_cluster_name" {
  description = "The name of the source cluster"
  type        = string
}

variable "environment" {
  description = "The name of the the Environment"
  type        = string
}


variable "rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "ssh access"
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "postgresql access"
    },
  ]
}
