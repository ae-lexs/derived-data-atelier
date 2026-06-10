resource "aws_cloudwatch_log_group" "api" {
  name              = "/dda/api"
  retention_in_days = 7
}

resource "aws_cloudwatch_dashboard" "dda" {
  dashboard_name = "dda-overview"
  dashboard_body = file("${path.module}/grafana/dda-dashboard.json")
}

# ADOT collector container fragment, consumed by infra/oltp-service in Module 03.
# Pinning the image tag here keeps the apparatus stack the single source of truth
# for the observability collector version across Modules 03 to 05.
locals {
  adot_image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.47.0"

  adot_container = {
    name      = "adot-collector"
    image     = local.adot_image
    essential = true
    cpu       = 256
    memory    = 512
    portMappings = [
      { containerPort = 4318, protocol = "tcp" }, # OTLP HTTP
      { containerPort = 4317, protocol = "tcp" }, # OTLP gRPC
    ]
    command = ["--config=/etc/ecs/ecs-default-config.yaml"]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "adot"
      }
    }
  }
}
