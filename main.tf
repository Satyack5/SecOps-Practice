provider "aws" {
  region = var.region_name
}

terraform {
  backend "s3" {
    bucket         = "terraformstorebucket"
    key            = "workspace.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dynamodb-state-locking"
  }
}

resource "aws_vpc" "test" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = var.vpc_tag
    Service = "Terraform"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.test.id
  cidr_block              = var.subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.subnet_az

  tags = {
    Name    = var.subnet_tag
    Service = "Terraform"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.test.id

  tags = {
    Name    = var.igw_tag
    Service = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = var.rt_cidr_block
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name    = var.rt_tag
    Service = "Terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.test.id

  ingress {
    description = "Allow all inbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "SG-Terra"
    Service = "Terraform"
  }
}

resource "aws_instance" "my_inst" {
  ami                         = "ami-0866a3c8686eaeeba"
  availability_zone           = var.ec2_az
  instance_type               = var.ec2_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = ["${aws_security_group.allow_all.id}"]
  associate_public_ip_address = true
  tags = {
    Name       = var.ec2_name
    Env        = var.ec2_env
    Owner      = "aparnab"
    CostCenter = "ABCD"
  }
  #lifecycle {
  #create_before_destroy = true
  #prevent_destroy = true
  #}

  user_data = <<-EOF
#!/bin/bash
	sudo apt-get update
	sudo apt-get install -y nginx
	echo "<h1>${var.ec2_env}-Server-1</h1>" | sudo tee /var/www/html/index.html
	sudo systemctl start nginx
	sudo systemctl enable nginx
EOF

  # }
}