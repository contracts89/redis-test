terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "eu-west-1"
}

resource "aws_instance" "redis_ec2" {
  ami           = "ami-05842291b9a0bd79f"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.redis_sg.id]

  tags = {
    Name = "redis_test"
  }
}

resource "aws_vpc" "redis_vpc" {
  cidr_block = "10.0.0.0/28"

  tags = {
    Name = "redis_vpc"
  }
}

resource "aws_security_group" "redis_sg" {
  name = "redis_security_group"
  vpc_id = aws_vpc.redis_vpc.id

  tags = {
    "name" = "redis_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls" {
  security_group_id = aws_security_group.redis_sg.id
  cidr_ipv4         = aws_vpc.redis_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.redis_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redis_iam_role" {
  name               = "redis_iam_role"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}