terraform {
  backend "s3" {
bucket         = "veltri-minimarket-tfstate" #CAMBIAR NOMBRE POR NUESTRO S3 REAL NO OLVIDAR
    region         = "eu-east-1"
    encrypt        = true
  }
}