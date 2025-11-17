provider "aws" {
  region = "ap-south-1"
}


# VPC MODULE 

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "robot-shop-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24" ]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Project = "robot"
  }
}

# ALB MODULE 
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.0.0"

  name               = "robot-shop-alb"
  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

 security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }

  listeners = [
    {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "app"
      }
    }
  ]

  target_groups = {
    app = {
      port     = 80
      protocol = "HTTP"
      target_type = "instance"
      health_check = {
        path = "/"
      }
    }
  }

  tags = {
    Project = "robot"
  }
}

# AUTO SCALING GROUP MODULE 
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.0.0"

  name = "robot-shop-asg"

  vpc_zone_identifier = module.vpc.private_subnets

  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  health_check_type = "EC2"

  launch_template = {
    name_prefix   = "robot-shop-lt"
    image_id      = "ami-087d1c9a513324697" 
    instance_type = "t3.micro"
  }

  target_group_arns = module.alb.target_group_arns

  tags = [
    {
      key                 = "Project"
      value               = "robot"
      propagate_at_launch = true
    }
  ]
}

