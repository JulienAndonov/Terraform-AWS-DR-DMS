resource "aws_iam_role" "dms-vpc-role" {
  name        = "dms-vpc-role"
  description = "Allows DMS to manage VPC"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.dms-vpc-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_dms_endpoint" "source" {
  database_name = var.database_name
  endpoint_id   = "thedock-dms-endpoint-source"
  endpoint_type = "source"
  engine_name   = "aurora-postgresql"
  username      = var.source_db_username
  password      = var.source_db_password
  port          = 5432
  server_name   = module.source.cluster_endpoint
  ssl_mode      = "none"

  tags = {
    Name = "thedock-dms-source"
  }
}

resource "aws_dms_endpoint" "target" {
  database_name = var.database_name
  endpoint_id   = "thedock-dms-endpoint-target"
  endpoint_type = "target"
  engine_name   = "aurora-postgresql"
  username      = var.target_db_username
  password      = var.target_db_password
  port          = 5432
  server_name   = module.target.cluster_endpoint
  ssl_mode      = "none"

  tags = {
    Name = "thedock-dms-target"
  }
}

resource "aws_dms_replication_subnet_group" "dms_target" {
  replication_subnet_group_description = "Subnet Group meant for replication"
  replication_subnet_group_id          = "${var.default_subnet_group}"

  subnet_ids = data.aws_db_subnet_group.targetSubnetGroup.subnet_ids

  tags = {
    Environment = "banking-int"
  }
  depends_on = [ module.target ]
}

# Create a new replication instance
resource "aws_dms_replication_instance" "thedock" {
  allocated_storage           = 1200
  apply_immediately           = true
  auto_minor_version_upgrade  = true
  availability_zone           = data.aws_db_instance.target_rds_instance.availability_zone
  multi_az                    = false
  publicly_accessible         = false
  replication_instance_class  = "dms.t2.micro"
  replication_instance_id     = "thedock-dms-replication-instance-tf"
  replication_subnet_group_id = aws_dms_replication_subnet_group.dms_target.id
  vpc_security_group_ids     = [data.aws_security_group.selected_sg.id,data.aws_security_group.default.id]

  tags = {
    Name = "thedock-replication-instance"
  }
  depends_on = [module.target]
}

#resource "aws_dms_replication_task" "thedock" {
#  migration_type            = "full-load-and-cdc"
#  replication_instance_arn  = aws_dms_replication_instance.thedock.replication_instance_arn
#  replication_task_id       = "thedock-dms-replication-task-tf"
#  replication_task_settings = file("dms-task-settings.json")
#  table_mappings            = file("dms-table-mappings.json")
#  source_endpoint_arn       = aws_dms_endpoint.source.endpoint_arn
#  target_endpoint_arn       = aws_dms_endpoint.target.endpoint_arn
#
#  tags = {
#    Name = "thedock-replication-task"
#  }
#}