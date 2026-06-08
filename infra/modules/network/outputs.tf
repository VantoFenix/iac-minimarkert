output "vpc_id" {
  value       = aws_vpc.main.id
  description = "El ID de la VPC principal"
}

output "public_subnets" {
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  description = "IDs de las subredes publicas"
}

output "private_subnets_compute" {
  value       = [aws_subnet.private_3_lambda_ec2.id, aws_subnet.private_4_ec2_b.id]
  description = "IDs de las subredes privadas para procesamiento (EC2 y Lambda)"
}

output "private_subnets_data" {
  value       = [aws_subnet.private_5_data.id, aws_subnet.private_6_data_b.id]
  description = "IDs de las subredes privadas para la capa de datos (Aurora y Cache)"
}