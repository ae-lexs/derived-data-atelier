resource "aws_security_group" "alb" {
  name        = "dda-oltp-alb"
  description = "ALB ingress 0.0.0.0/0 80; egress to ECS service SG"
  vpc_id      = data.terraform_remote_state.data_model.outputs.vpc_id

  ingress {
    description = "HTTP from anywhere - codelab smoke + k6 load"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Egress rule broken out so it can reference aws_security_group.service
# without creating a creation-order cycle with that SG's ingress rule.
resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  security_group_id            = aws_security_group.alb.id
  description                  = "to ECS task on app port"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.service.id
}

resource "aws_lb" "main" {
  name               = "dda-oltp"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "api" {
  name        = "dda-oltp-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.data_model.outputs.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/healthz"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 10
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
