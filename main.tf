provider "aws" {
  region  = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

#Save state in S3 bucket
terraform{
    backend "s3"{
      bucket = "arena-terraform-prod"
      key    = "jenkins-server.tfstate"
      region = "us-east-1"
    }
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_instance" "web-server" {
  ami                         = "ami-053b0d53c279acc90"
  instance_type               = "t2.micro"
  #security_groups             = ["${aws_security_group.web-server-sg.name}"]
  #key_name                    = "web-server-key"
  tags                        = {
    Name                      = "web-server"
  }
}