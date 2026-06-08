# 1Módulo de Red 
module "network" {
  source     = "./modules/network"
  aws_region = var.aws_region
  ambiente   = var.ambiente
  proyecto   = var.proyecto
}

# 2Módulo de Datos 
module "data" {
  source   = "./modules/data"
  ambiente = var.ambiente
  proyecto = var.proyecto
  # Aquí se le pasarán los IDs de subredes del módulo network más adelante
}

# 3Módulo de Cómputo 
module "compute" {
  source   = "./modules/compute"
  ambiente = var.ambiente
  proyecto = var.proyecto
  # Aquí se le pasarán la VPC y los Security Groups más adelante
}

# 4 Módulo de Borde y Asincronía 
module "edge" {
  source   = "./modules/edge"
  ambiente = var.ambiente
  proyecto = var.proyecto
}