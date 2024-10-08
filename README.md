# Terraform Playground

This repo is a sample Terraform project that sets up the following:
* A VPC in AWS
* A docker image for a simple profile service (using one of the example services from Go Kit). Terraform is responsible for both building the docker image and pushing it to ECR
* An ECS service to run the profile service in Fargate (under the created VPC) behind an application load balancer

## Project set up

Based on an example in [this article][1] I set up the project to support multiple environments (e.g. development, staging, production) but so far I've only got it working in the development environment. That means that I haven't yet done everything necessary to ensure 
* that there are no naming collisions if muliple environments deploy to the same AWS account.
* that it's straightforward to deploy to environments in multiple accounts. (That would be my prefrence in a real deployment, but I only have one personal AWS account, so...)

I used two pre-existing modules from the Hashicorp Terraform Registry for creating a [VPC](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) and an [ECR repository](https://registry.terraform.io/modules/terraform-aws-modules/ecr/aws/latest). These two modules are pulled directly from the registry and don't appear in my repo. 

I also created two modules that do appear in in the repo under `modules`: 
* `tf-docker` For bulding and pushing a docker image to ECR. Note that this module includes a Git submodule to my fork of [Go Kit Examples](https://github.com/jonathan-k-shapiro/go-kit-examples/tree/3b8f291d2b369eb0ccd867d85ab9c7b10e38b1b3). My fork just adds a `Dockerfile` to build the `profilesvc` example as an image.
* `ecs` for building the ECS service and its associated infrastructure.

## Running Terraform

There's a few ways to do it. But here's how I'm doing it from my laptop.

In my personal AWS account, I have an organization set up with just that one account belonging to it. I use IAM Identity Center as an identity source and avoid having any long-lived credentials. But that means I need to get Terraform to run under a role I assume. My current way to do this is using [`aws-vault`](https://github.com/99designs/aws-vault) which forces me to log in via SSO and then creates a sub-shell with temporary credentials which have permissions to do what Terraform needs to do.

So, for example:
```
cd environments/development
aws-vault exec <username> --  terraform init
aws-vault exec <username> --  terraform plan -out development.tfplan
aws-vault exec <username> --  terraform apply development.tfplan
```

You can also execute `aws-vault exec <username>` on a line by itself to get dropped into a subshell that just lets you run the un-decorated terraform commands

```
cd environments/development
aws-vault exec <username>
# Now in a subshell
terraform init
terraform plan -out development.tfplan
terraform apply development.tfplan
```

## How to test it
As of this writing, the profile service is running in my account. (I will tear it down at some point soon so the URLs below are not guaranteed to work indefinitely).

Create a Profile:

```bash
$ curl -d '{"id":"1234","Name":"Go Kit"}' -H "Content-Type: application/json" -X POST http://profilesvc-load-balancer-1585549468.us-west-2.elb.amazonaws.com:8080/profiles/
{}
```

Get the profile you just created

```bash
$ curl profilesvc-load-balancer-1585549468.us-west-2.elb.amazonaws.com:8080/profiles/1234
{"profile":{"id":"1234","name":"Go Kit"}}
```

## References:

I've relied on several [really][1] [nice][2] [examples][4] I [found][3] on the Web.

[1]: https://medium.com/@b0ld8/terraform-manage-multiple-environments-63939f41c454 "Setting up Terraform to manage multiple environments"
[2]: https://anthony-f-tannous.medium.com/how-to-build-and-push-a-docker-image-to-ecr-with-terraform-38f0083314e9 "How to build and push a docker image to ECR with terraform"
[3]: https://medium.com/@olayinkasamuel44/using-terraform-and-fargate-to-create-amazons-ecs-e3308c1b9166 "Using Terraform and Fargate to create Amazon's ECS"
[4]: https://gokit.io/examples "Go Kit examples"

## Notes:

### Terraform IAM role

There's a `terraform` role created manually via click-ops in the target account. To allow me to authenticate with SS0 and then assume this role and run terraform locally, I have the following trust policy on the `terraform` role

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::461768693077:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringLike": {
                    "aws:PrincipalArn": "arn:aws:iam::461768693077:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AdministratorAccess_24cd43b476670226"
                }
            }
        }
    ]
}
```
The ARN in the condition above is simply copied from the IAM role created by IAM Identity Center for the `AdministatorAccess` permission set.

### About aliased providers and modules

Currently there are two things I'd like to do that seem to be incompatible:
* Have multiple providers (for a world with multiple accounts) and obtain the aws region from the current provider.
* Use the existing [Terraform registry module for VPCs](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) `terraform-aws-modules/vpc/aws`

The problem is:

To obtain the aws region, I need to create a data source and that _apparently_ requires adding an alias to the provider...

```
provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}

data "aws_region" "usw2" {
  provider = aws.usw2
}

# Specify region as data.aws_region.usw2.name elsewhere
```

However, I can't (I don't think, anyway) pass the provider to the VPC module, and when the aliased provider is used, the module creates the vpc in `us-east-1` and then TF barfs when trying to create
subnets in `us-west-2` AZs.

I'm sure there are several ways to resolve this, but for now I'm just going to use an un-aliased provder and let the VPC module inherit the default provider. :oof:

### Needed to explicitly import two routes

After the first TF `apply`, the following imports were necessary to recognize two routes created in the apply but not included by TF in the state for some reason. Note the id format ROUTETABLEID_DESTINATION is required for the import command

```
import {
  to = module.vpc.aws_route.private_nat_gateway[1]
  id = "rtb-06f64e12e8afe39d4_0.0.0.0/0"
}
import {
  to = module.vpc.aws_route.private_nat_gateway[2]
  id = "rtb-0af99a6652c353641_0.0.0.0/0"
}
```
After a subsequent destroy and re-creation, this was no long necessary for the newly created routes. Not sure why. :shrug: