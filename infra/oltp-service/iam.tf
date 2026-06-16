# Task execution role — AWS-managed AmazonECSTaskExecutionRolePolicy
# is sufficient for ECR pull + CloudWatch Logs write.
resource "aws_iam_role" "task_execution" {
  name               = "dda-oltp-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role — minimal: only rds-db:connect on the dda_app database user.
resource "aws_iam_role" "task" {
  name               = "dda-oltp-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "rds_iam_auth" {
  statement {
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${data.terraform_remote_state.data_model.outputs.cluster_resource_id}/dda_app"
    ]
  }
}

resource "aws_iam_role_policy" "task_rds_iam" {
  name   = "rds-iam-connect"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.rds_iam_auth.json
}

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_caller_identity" "current" {}
