# Terraform with multiple environments example

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

[How to build and push a docker image to ECR with terraform](https://anthony-f-tannous.medium.com/how-to-build-and-push-a-docker-image-to-ecr-with-terraform-38f0083314e9)

[Using Terraform and Fargate to create Amazon's ECS](https://medium.com/@olayinkasamuel44/using-terraform-and-fargate-to-create-amazons-ecs-e3308c1b9166)

[gokit.io/examples](https://gokit.io/examples) for a simple profile service that we can run

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
* Have multiple providers (for a world with multiple accounts) and obtain the aws region from the current provider rather than hard-coding it in places
* Use the Terraform registry module for VPCs (`terraform-aws-modules/vpc/aws`)

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

I'm sure there are several ways to resolve this, but for now I'm just going to use an un-aliased provder and hard-code the region in places where I need it. :oof:

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
After subsequent destroy and re-creation, this was no long necessary for the newly created routes. Not sure why. :shrug: