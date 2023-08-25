provider "aws" {
  region  = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.13.1"
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

###### REDE #######

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

##### REDE PUBLICA #######

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public_subnet_a"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id

  lifecycle {
    # ignore_changes        = ["subnet_id", "route_table_id"]
    create_before_destroy = true
  }
}
##### NAT #####
resource "aws_eip" "nat_eip" {
  domain   = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.index.id

  tags = merge(
    var.tags,
    {
      "Name"    = "${var.name}-NATGW-${count.index}"
      "EnvName" = var.name
    },
  )
}

resource "aws_subnet" "private_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.20.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "private_subnet_a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.40.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "private_subnet_b"
  }
}




###### ROLE #####

resource "aws_iam_role" "ec2_role" {
  name               = "SSMCore-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_enable" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_patch_enable" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
}


resource "aws_iam_instance_profile" "ec2_iam_profile" {
  name = "SSMCore-profile"
  role = aws_iam_role.ec2_role.name
}

###### INSTANCIAS ########

resource "aws_instance" "web-server" {
  ami                         = "ami-08a52ddb321b32a8c"
  instance_type               = "t2.micro"
  security_groups             = [aws_security_group.web-server-sg.id]
  key_name                    = "web-server-key"
  subnet_id                   = aws_subnet.public.id
  iam_instance_profile        = aws_iam_instance_profile.ec2_iam_profile.name
  depends_on                  = [aws_subnet.public]
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/bash
# Use this for your user data (script from top to bottom)
# install httpd (Linux 2 version)
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
EOF
  
  tags                        = {
    Name                      = "web-server"
  }
}

resource "aws_key_pair" "web-server-key" {
  key_name = "web-server-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDB2++8yo3Nub3Rsxak8s1tcxelmCTS3IpFMw06DOKgcQqXbzuNYPQh51m0KbfzYlPl+upAndaJ/0wezd32sF55XlAkyhcsMzY2hX+cqoCKjTrh00MTgxLJIE57eGqgbeEwxeiobXLYtxaBD4EQ3VeHthdsFAMX+gXEmcG6+2ZpJA6e2U+/6+cQc+sSghBW8Lo9FounqEYsIJpgNuB2tM6MFBtKKNuiFzuitrqDRg6SDBUWupjxd3klNVnlfDOKgnVhdP5ygYNmgQJVgqHFlCwG4Mw9ZEb1281xI1DG0n1udKnPZF6IuspKUMkSTXR/SXf/C/fnnv+2cQm7F8HhfPUKqxYwPZ73bv45J9N0xFezcDbMjWftD+PsobY//0x8gx5CNwd9jd58fl0U5i1tEfOJ1IH5OO97QRbn8J1mpIYtapSwLAvZn7mvio8j+Gad69zCduoh32sGnHGu+op/f+03YA38gNWyTc9oDIkwrDe/s21gJbnai2FQ24pb0qqoRvM= allan@ubuntu"
}

resource "aws_security_group" "web-server-sg" {
  description           = "Allow all outbound traffic and inbound 22/80"
  name                  = "web-server-sg"
  vpc_id                = aws_vpc.main.id
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
    Name        = "web_server"
  }
}

######### RDS ############

# resource "aws_db_instance" "default" {
#   allocated_storage    = 20
#   storage_type         = "gp2"
#   engine               = "mysql"
#   engine_version       = "5.7"
#   instance_class       = "db.t2.micro"
#   db_name              = "mydb"
#   username             = "foo"
#   password             = "foobarbaz"
#   parameter_group_name = "default.mysql5.7"
#   skip_final_snapshot  = true
#}

#### OUTPUTS #####

output "ip_instance" {
  value = aws_instance.web-server.public_ip
}

# output "endpoint" {
#   value = aws_db_instance.default.endpoint
# }