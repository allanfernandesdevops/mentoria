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
  security_groups             = ["${aws_security_group.web-server-sg.name}"]
  key_name                    = "web-server-key"
  tags                        = {
    Name                      = "web-server"
  }
}

resource "aws_key_pair" "web-server-key" {
  key_name = "web-server-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDB2++8yo3Nub3Rsxak8s1tcxelmCTS3IpFMw06DOKgcQqXbzuNYPQh51m0KbfzYlPl+upAndaJ/0wezd32sF55XlAkyhcsMzY2hX+cqoCKjTrh00MTgxLJIE57eGqgbeEwxeiobXLYtxaBD4EQ3VeHthdsFAMX+gXEmcG6+2ZpJA6e2U+/6+cQc+sSghBW8Lo9FounqEYsIJpgNuB2tM6MFBtKKNuiFzuitrqDRg6SDBUWupjxd3klNVnlfDOKgnVhdP5ygYNmgQJVgqHFlCwG4Mw9ZEb1281xI1DG0n1udKnPZF6IuspKUMkSTXR/SXf/C/fnnv+2cQm7F8HhfPUKqxYwPZ73bv45J9N0xFezcDbMjWftD+PsobY//0x8gx5CNwd9jd58fl0U5i1tEfOJ1IH5OO97QRbn8J1mpIYtapSwLAvZn7mvio8j+Gad69zCduoh32sGnHGu+op/f+03YA38gNWyTc9oDIkwrDe/s21gJbnai2FQ24pb0qqoRvM= allan@ubuntu"
}

resource "aws_security_group" "web-server-sg" {
  description = "Allow all outbound traffic and inbound 22/80"
  name = "web-server-sg"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sg_jenkins"
  }
}