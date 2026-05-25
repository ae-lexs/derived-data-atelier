resource "random_password" "master" {
  length  = 32
  special = false # avoid shell-special characters in load scripts
}

resource "aws_secretsmanager_secret" "master" {
  name        = "dda/data-model/master"
  description = "Aurora master credentials for DDA — used by golang-migrate and seed/load.sh only"
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = "dda_master"
    password = random_password.master.result
  })
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "dda-aurora"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # required for Serverless v2 — see ADR-DDA-005
  engine_version     = "16.4"
  database_name      = "tpch"
  master_username    = "dda_master"
  master_password    = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  storage_encrypted   = true
  skip_final_snapshot = true # codelab — not production
  apply_immediately   = true

  # M02 amendment: IAM-token auth for the api/ service. dda_master keeps
  # password auth (used by golang-migrate and seed/load.sh).
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration {
    min_capacity             = var.min_capacity # 0 for idle, 1.0 during measurement (Modules 03–05)
    max_capacity             = 1.0              # ADR-DDA-005 — measurable contention at 1 ACU ceiling
    seconds_until_auto_pause = 300              # 5 min idle → pause to zero ACU
  }

  # Aurora applies minor-version upgrades on its own maintenance window; we
  # don't want terraform to fight that drift on every plan.
  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_rds_cluster_instance" "writer" {
  cluster_identifier  = aws_rds_cluster.main.id
  identifier          = "dda-aurora-writer"
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.main.engine
  engine_version      = aws_rds_cluster.main.engine_version
  publicly_accessible = false

  # M02 amendment: Performance Insights on the writer. PI lives in
  # data-model (not infra/apparatus) because two Terraform stacks cannot
  # own the same physical resource without fighting on every plan.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # days; free-tier ceiling
}
