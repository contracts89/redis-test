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
  region = "eu-west-1"  # Change to your desired region
}

# Create a Virtual Private Cloud (VPC)
resource "aws_vpc" "redis_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.redis_vpc.id
  cidr_block        = "10.0.8.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Public Subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.redis_vpc.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Private Subnet"
  }
}

# Create an IAM role for EC2 with SSM permissions
resource "aws_iam_role" "ssm_role" {
  name = "EC2_SSM_Role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      },
    ]
  })
}

# Attach SSM policies to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Create an EC2 instance in the private subnet
resource "aws_instance" "redis_ec2" {
  ami           = "ami-05842291b9a0bd79f"  # Change this to a valid AMI ID
  instance_type = "t2.micro" 
  subnet_id     = aws_subnet.private_subnet.id
  
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  
  tags = {
    Name = "redis_ec2"
  }
}

# Create an IAM instance profile for the EC2 instance
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_security_group" "allow_ssm" {
  name        = "allow_ssm"
  description = "Allow SSM access"
  vpc_id      = aws_vpc.redis_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outgoing traffic
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }
}

# Create interface VPC Endpoint for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.redis_vpc.id
  service_name        = "com.amazonaws.eu-west-1.ssm"
  subnet_ids          = [aws_subnet.private_subnet.id]
  security_group_ids  = [aws_security_group.allow_ssm.id]
  vpc_endpoint_type   = "Interface"
  
  private_dns_enabled = true
}

# Create interface VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.redis_vpc.id
  service_name        = "com.amazonaws.eu-west-1.ec2messages"
  subnet_ids          = [aws_subnet.private_subnet.id]
  security_group_ids  = [aws_security_group.allow_ssm.id]
  vpc_endpoint_type = "Interface"

  private_dns_enabled = true
}

# Create interface VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.redis_vpc.id
  service_name        = "com.amazonaws.eu-west-1.ssmmessages"
  subnet_ids          = [aws_subnet.private_subnet.id]
  security_group_ids  = [aws_security_group.allow_ssm.id]
  vpc_endpoint_type = "Interface"

  private_dns_enabled = true
}