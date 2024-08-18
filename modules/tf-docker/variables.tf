variable "environment" {
  description = "The environment to deploy the resources to"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy the resources to"
  type        = string
}

variable "ecr_reg_id" {
  description = "The ECR registry id"
  type        = string
}

variable "ecr_repo_url" {
  description = "The ECR repository URL"
  type        = string
}

variable "image_tag" {
  description = "The tag to apply to the image"
  type        = string
} 

variable "force_image_rebuild" {
  type    = bool
  default = false
}
