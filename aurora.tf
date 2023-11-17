resource "aws_rds_cluster_parameter_group" "pg14logical" {
  name        = "aurorapgsql14logicalcluster"
  family      = "aurora-postgresql14"
  description = "RDS cluster parameter group for logical replication"

  parameter {
    name  = "max_replication_slots"
    value = "10"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_wal_senders"
    value = "15"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "max_worker_processes"
    value = "10"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "rds.logical_replication"
    value = "1"
    apply_method = "pending-reboot"

  }
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pglogical"
    apply_method = "pending-reboot"
  }
}

locals {
  destination_endpoint = "${trim(module.target.cluster_endpoint,":5432")}"
  rds_cidr_blocks = [for s in data.aws_subnet.rds_subnet_array : s.cidr_block]
  all_cidr_blocks = concat(tolist([data.aws_subnet.ec2_subnet.cidr_block]), local.rds_cidr_blocks)
}



resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.public_key
}

resource "aws_security_group" "pgsql_allow" {
  name        = "allow_postgresql_ingress"
  description = "Allow PostgreSQL & SSH access"
  vpc_id      = data.aws_vpc.main_vpc.id

  tags = {
    Name = "allow_ssh_postgresql"
  }
}

resource "aws_security_group_rule" "ingress_rules" {
  count             = length(var.rules)
  type              = "ingress"
  from_port         = var.rules[count.index].from_port
  to_port           = var.rules[count.index].to_port
  protocol          = var.rules[count.index].protocol
  cidr_blocks       = local.all_cidr_blocks
  description       = var.rules[count.index].description
  security_group_id = data.aws_security_group.selected_sg.id
}

resource "aws_security_group_rule" "egress_rules" {
  count             = length(var.rules)
  type              = "egress"
  from_port         = var.rules[count.index].from_port
  to_port           = var.rules[count.index].to_port
  protocol          = var.rules[count.index].protocol
  cidr_blocks       = local.all_cidr_blocks
  description       = var.rules[count.index].description
  security_group_id = data.aws_security_group.selected_sg.id
}


resource "aws_instance" "ec2_instance" {
  ami                    = var.ami
  subnet_id              = data.aws_subnets.ec2_dms_subnet.ids[0]
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  availability_zone      = data.aws_db_instance.target_rds_instance.availability_zone
  vpc_security_group_ids = [data.aws_security_group.selected_sg.id,data.aws_security_group.default.id]

  tags = {
    Name        = "psqlclient"
    Environment = "Backup"
    Terraform   = "true"
  }
}


resource "local_file" "executable_file" {
  file_permission = "644"
  content = templatefile("${path.cwd}/source.tftpl", {
    source_endpoint         = "${module.target.cluster_reader_endpoint}"
    database_name           = "${var.database_name}"
    database_admin_username = "${var.target_db_username}"
    database_admin_password = "${var.target_db_password}"
  })
  filename = "source.sql"
}

resource "null_resource" "database_configuration"{
  
    triggers = {
      always_run = timestamp()
    }

    connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = "${file(var.private_key_path)}"
      host     = aws_instance.ec2_instance.private_ip
    }

    provisioner "file" {
    source      = "${path.cwd}/source.sql"
    destination = "/tmp/destination.sql"
    }

    provisioner "remote-exec" {
    inline = ["sudo yum -y update",
    "sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm",
    "sudo yum install -y postgresql14",
	  "sudo yum install -y telnet",
	  "sudo yum install -y unzip",
    "PGPASSWORD=\"${var.target_db_password}\" psql -U${var.target_db_username} -h ${module.target.cluster_endpoint} -d postgres  -f /tmp/source.sql"]
  }
  depends_on = [module.target]
}


module "source" {
  source                      = "terraform-aws-modules/rds-aurora/aws"
  name                        = "banking-int-source"
  engine                      = "aurora-postgresql"
  engine_version              = "14.8"
  manage_master_user_password = false
  master_username             = "${var.target_db_username}"
  master_password             = "${var.target_db_password}"
  snapshot_identifier         = data.aws_db_cluster_snapshot.thedock_snapshot.id
  
  //Instances
  instance_class = "db.t4g.medium"
  instances = {
    one = {
      availability_zone = "eu-central-1a"
    }
  }

  vpc_id                          = data.aws_vpc.main_vpc.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.pg14logical.name
  vpc_security_group_ids          = [data.aws_security_group.selected_sg.id,data.aws_security_group.default.id]
  db_subnet_group_name            = "${var.environment}-db-main"
  skip_final_snapshot             = true

  tags = {
    Environment = "banking-int-source"
    Terraform   = "true"
  }
}


module "target" {
  source                      = "terraform-aws-modules/rds-aurora/aws"
  name                        = "banking-int-target"
  engine                      = "aurora-postgresql"
  engine_version              = "14.8"
  manage_master_user_password = false
  master_username             = "${var.target_db_username}"
  master_password             = "${var.target_db_password}"
  snapshot_identifier         = data.aws_db_cluster_snapshot.thedock_snapshot.id
  
  
  //Instances
  instance_class = "db.t4g.medium"
  instances = {
    one = {
      availability_zone = "eu-central-1a"
    }
  }

  vpc_id                          = data.aws_vpc.main_vpc.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.pg14logical.name
  vpc_security_group_ids          = [data.aws_security_group.selected_sg.id,data.aws_security_group.default.id]
  db_subnet_group_name            = "${var.environment}-db-main"
  skip_final_snapshot             = true

  tags = {
    Environment = "banking-int-target"
    Terraform   = "true"
  }
}