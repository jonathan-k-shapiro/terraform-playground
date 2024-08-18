variable environment {
  description = "The environment to deploy to"
  type        = string
}

variable aws_region {
  description = "The AWS region to deploy to"
  type        = string
}

variable app_port {
  description = "The port the application will listen on"
  type        = number
  default     = 8080
}

variable alb_port {
  description = "The port the ALB will listen on"
  type        = number
  default     = 80
}

variable ecr_repo_url {
  description = "The URL of the ECR repository"
  type        = string
}

variable image_tag {
  description = "The tag of the Docker image to deploy"
  type        = string
}

variable vpc_id {
  description = "The ID of the VPC to deploy into"
  type        = string
}

variable public_subnets {
  description = "The IDs of the public subnets to deploy into"
  type        = list(string)
}

variable private_subnets {
  description = "The IDs of the private subnets to deploy into"
  type        = list(string)
}

variable fargate_cpu {
  description = "The amount of CPU to allocate to the Fargate task"
  type        = string
  default     = "256"
}

variable fargate_memory {
  description = "The amount of memory to allocate to the Fargate task"
  type        = string
  default     = "512"
}

variable app_image {
  description = "The Docker image to deploy"
  type        = string
}

variable app_count {
  description = "The number of tasks to run"
  type        = number
  default     = 1
}