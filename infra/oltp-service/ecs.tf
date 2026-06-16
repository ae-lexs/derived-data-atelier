resource "aws_ecs_cluster" "main" {
  name = "dda-oltp"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Fargate's awslogs driver auto-creates streams under the awslogs-stream-prefix
# set in the container's logConfiguration. No explicit aws_cloudwatch_log_stream
# resource needed.

resource "aws_security_group" "service" {
  name        = "dda-oltp-service"
  description = "ECS service ingress from ALB; egress to Aurora and internet (ECR, CloudWatch, Grafana Cloud OTLP)"
  vpc_id      = data.terraform_remote_state.data_model.outputs.vpc_id

  egress {
    description = "all outbound - ECR, CloudWatch, Aurora 5432, OTLP egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Ingress rule broken out so it can reference aws_security_group.alb
# without creating a creation-order cycle with that SG's egress rule.
resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id            = aws_security_group.service.id
  description                  = "from ALB"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# The Aurora SG from infra/data-model accepts ingress from the VPC CIDR
# (10.42.0.0/16). The ECS task's ENI gets an IP in 10.42.20.x/21.x, which
# falls in that CIDR — no additional Aurora SG rule needed.

resource "aws_ecs_task_definition" "api" {
  family                   = "dda-oltp-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # Apple Silicon dev host builds ARM64 images by default. Pin Fargate to
  # ARM64 too so docker build does not need --platform linux/amd64; also
  # ~20% cheaper than X86_64 on Fargate Graviton pricing.
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "HTTP_ADDR",      value = ":8080" },
        { name = "PG_HOST",        value = data.terraform_remote_state.data_model.outputs.cluster_endpoint },
        { name = "PG_PORT",        value = "5432" },
        { name = "PG_USER",        value = "dda_app" },
        { name = "PG_DATABASE",    value = "tpch" },
        { name = "PG_SSL_MODE",    value = "require" },
        { name = "USE_IAM_AUTH",   value = "true" },
        { name = "AWS_REGION",     value = "us-east-1" },
        { name = "OTLP_ENDPOINT",  value = "http://localhost:4318" },
        { name = "SERVICE_NAME",   value = "dda-api" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.apparatus.outputs.api_log_group_name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "api"
        }
      }
      # ADOT sidecar temporarily removed for diagnostics — re-add after we
      # confirm the api/ container can start cleanly.
      # dependsOn = [
      #   { containerName = "adot-collector", condition = "START" }
      # ]
    },
    # data.terraform_remote_state.apparatus.outputs.adot_container_fragment,
  ])
}

resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.task_rds_iam, # avoid IAM consistency race on first task start
  ]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
