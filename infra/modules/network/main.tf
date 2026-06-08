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

# 5 Puerta de Enlace a Internet 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.proyecto}-${var.ambiente}-igw" }
}

# 6 IPs Elásticas para los NAT Gateways
resource "aws_eip" "nat_1" { domain = "vpc" }
resource "aws_eip" "nat_2" { domain = "vpc" }

# 7 NAT Gateways (Ubicados en redes públicas para dar salida segura a las privadas)
resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "${var.proyecto}-${var.ambiente}-nat-gw-1" }
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id
  tags          = { Name = "${var.proyecto}-${var.ambiente}-nat-gw-2" }
}

# 8 Tablas de Enrutamiento Públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.proyecto}-${var.ambiente}-public-rt" }
}

resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# 9 Amazon API Gateway 
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.proyecto}-${var.ambiente}-api"
  description = "Punto de entrada unico para el flujo dinamico de Veltri-Minimarket"

  endpoint_configuration {
    types = ["REGIONAL"] 
  }
}