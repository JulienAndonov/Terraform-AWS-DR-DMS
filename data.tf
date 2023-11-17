data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-main"]
  }
}

data "aws_subnets" "rds_subnets" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-main-db*"]
  }
}

data "aws_subnet" "ec2_subnet" {
  id = data.aws_subnets.private_subnets.ids[0]
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "tag:Name"
    values = ["*main-private*"]
  }
}

data "aws_db_instance" "source_rds_instance" {
  tags = {
    Environment = "banking-int-source"
  }

  depends_on = [module.source]
}

data "aws_db_instance" "target_rds_instance" {
  tags = {
    Environment = "banking-int-target"
  }
  depends_on = [module.target]
}


data "aws_db_subnet_group" "targetSubnetGroup" {
  name = module.target.db_subnet_group_name
}

data "aws_security_group" "selected_sg" {
  vpc_id = data.aws_vpc.main_vpc.id

  filter {
    name   = "tag:Name"
    values = ["allow_ssh_postgresql"]

  }
  depends_on = [aws_security_group.pgsql_allow]
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.main_vpc.id
  name = "default"
}

data "aws_subnet" "rds_subnet_array" {
  for_each = toset(data.aws_subnets.rds_subnets.ids)
  id       = each.value
}

data "aws_vpc" "main_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-main"]
  }
}

data "aws_subnets" "ec2_dms_subnet" {
  filter {
    name = "tag:Name"
    values = ["*main-db-eu-central*"]
  }

  filter {
    name = "availability-zone"
    values = ["${var.target_availability_zone}"]
  }
}

data "aws_db_subnet_group" "database" {
  name = "${var.environment}-db-main"
}


data "aws_db_cluster_snapshot" "thedock_snapshot" {
  db_cluster_snapshot_identifier = "banking-int"
}