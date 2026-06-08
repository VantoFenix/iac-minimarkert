# 1. Creación de la VPC Principal (Aislamiento de red)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.proyecto}-${var.ambiente}-vpc"
    Ambiente    = var.ambiente
  }
}

# 2. Subredes Públicas (Para dar la cara a internet y alojar los NAT Gateways)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.proyecto}-${var.ambiente}-public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-east-1b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.proyecto}-${var.ambiente}-public-subnet-2" }
}

# 3. Subredes Privadas Zona A 
resource "aws_subnet" "private_3_lambda_ec2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-east-1a"

  tags = { Name = "${var.proyecto}-${var.ambiente}-private-subnet-3" }
}

resource "aws_subnet" "private_5_data" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "eu-east-1a"

  tags = { Name = "${var.proyecto}-${var.ambiente}-private-subnet-5" }
}

# 4. Subredes Privadas Zona B (eu-east-1b)
resource "aws_subnet" "private_4_ec2_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-east-1b"

  tags = { Name = "${var.proyecto}-${var.ambiente}-private-subnet-4" }
}

resource "aws_subnet" "private_6_data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "eu-east-1b"

  tags = { Name = "${var.proyecto}-${var.ambiente}-private-subnet-6" }
}