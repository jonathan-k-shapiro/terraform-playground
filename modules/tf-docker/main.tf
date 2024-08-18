
locals {
  dkr_img_src_path   = "${path.module}/go-kit-examples"
  dkr_img_src_sha256 = sha256(join("", [for f in fileset(".", "${local.dkr_img_src_path}/**") : file(f)]))

  ecr_reg = "${var.ecr_reg_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  dkr_build_cmd = <<-EOT
        docker buildx build -t ${var.ecr_repo_url}:${var.image_tag} \
            -f ${local.dkr_img_src_path}/Dockerfile ${local.dkr_img_src_path}

        aws ecr get-login-password --region ${var.aws_region} | \
            docker login --username AWS --password-stdin ${local.ecr_reg}

        docker push ${var.ecr_repo_url}:${var.image_tag}            

    EOT
}

# local-exec for build and push of docker image
resource "null_resource" "build_push_dkr_img" {
  triggers = {
    detect_docker_source_changes = var.force_image_rebuild == true ? timestamp() : local.dkr_img_src_sha256
  }
  provisioner "local-exec" {
    command = local.dkr_build_cmd
  }
}

output "trigged_by" {
  value = null_resource.build_push_dkr_img.triggers
}
