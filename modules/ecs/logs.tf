# logs.tf

# Set up CloudWatch group and log stream and retain logs for 30 days
resource "aws_cloudwatch_log_group" "cb_log_group" {
  name              = "/ecs/profilesvc"
  retention_in_days = 30

  tags = {
    Name = "profilesvc-log-group"
  }
}

resource "aws_cloudwatch_log_stream" "cb_log_stream" {
  name           = "profilesvc-log-stream"
  log_group_name = aws_cloudwatch_log_group.cb_log_group.name
}