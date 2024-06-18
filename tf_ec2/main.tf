provider "aws" {
  region = "us-east-1"  # Ensure this is the correct region
}

###########################################   VPC SECTION   ###################################


variable "test_vpc_cidr" {
    type    = string
    default = "10.0.0.0/16"
}

resource "aws_vpc" "test_vpc" {
    cidr_block       = var.test_vpc_cidr
    tags = {
    Name = "test_vpc"
  }
}

############################################# SUBNET SECTION ########################################

variable "test_vpc_subnet1_cidr" {
    type = string
    default = "10.0.1.0/24"
}

resource "aws_subnet" "test_vpc_subnet1" {
    vpc_id = aws_vpc.test_vpc.id
    cidr_block = var.test_vpc_subnet1_cidr
    availability_zone = "us-east-1a"
    tags = {
    Name = "test_vpc_subnet1"
  }
}

variable "test_vpc_subnet2_cidr" {
    type    = string
    default = "10.0.2.0/24"
}

resource "aws_subnet" "test_vpc_subnet2" {
    vpc_id = aws_vpc.test_vpc.id
    cidr_block = var.test_vpc_subnet2_cidr
    availability_zone = "us-east-1b"
    tags = {
    Name = "test_vpc_subnet2"
  }
}

###########################################   IGW SECTION   ###################################

resource "aws_internet_gateway" "test_vpc_igw" {
    vpc_id = aws_vpc.test_vpc.id
    tags = {
    Name = "test_vpc_igw"
  }
}

########################################### ROUTE TABLE SECTION ###################################

resource "aws_route_table" "test_vpc_RT" {
    vpc_id = aws_vpc.test_vpc.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.test_vpc_igw.id
    }
    tags = {
    Name = "test_vpc_RT"
  }
}

resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.test_vpc_subnet1.id
  route_table_id = aws_route_table.test_vpc_RT.id
}

resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.test_vpc_subnet2.id
  route_table_id = aws_route_table.test_vpc_RT.id
}

################################# security group ########################################

resource "aws_security_group" "security_gp" {
  vpc_id = aws_vpc.test_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security-gp"
  }
}

###################################### KEY_PAIR #########################################

variable "key_name" {
    type = string
    default = "terraform_instance_key"
}

resource "tls_private_key" "terraform_instance_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.terraform_instance_key.private_key_pem
  filename = "${path.module}/my-key-pair.pem"
}

resource "aws_key_pair" "instance_key" {
  key_name   = var.key_name
  public_key = tls_private_key.terraform_instance_key.public_key_openssh # Path to your public key file
}

################################## EC2 Instance section #################################

variable "instance_type" {
    type = string
    default = "t2.micro"
}

variable "ami" {
    type = string
    default = "ami-04b70fa74e45c3917"
}

variable "user_data" {
    type = string
    default = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt install apache2 -y
                echo "Hello, World!" > /var/www/html/index.html
                EOF

}

resource "aws_instance" "test_instance"{
    ami           = var.ami
    instance_type = var.instance_type
    subnet_id     = aws_subnet.test_vpc_subnet1.id
    associate_public_ip_address = true
    user_data     = var.user_data
    key_name      = aws_key_pair.instance_key.key_name
    security_groups = [aws_security_group.security_gp.id]
    tags = {
      name = "test_instance"
    }
}


resource "null_resource" "public_instance_ip" {
  provisioner "local-exec" {
    command = "echo 'The instance type is ${aws_instance.test_instance.public_ip}'"
  }

  depends_on = [aws_instance.test_instance]
}