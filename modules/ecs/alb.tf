# alb.tf

resource "aws_alb" "main" {
    name        = "profilesvc-load-balancer"
    subnets         = var.public_subnets
    security_groups = [aws_security_group.lb.id]
}

resource "aws_alb_target_group" "app" {
    name        = "profilesvc-target-group"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = var.vpc_id
    target_type = "ip"

    # Our profilesvc does not have a health check endpoint
    # health_check {
    #     healthy_threshold   = "3"
    #     interval            = "30"
    #     protocol            = "HTTP"
    #     matcher             = "200"
    #     timeout             = "3"
    #     path                = var.health_check_path
    #     unhealthy_threshold = "2"
    # }
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}