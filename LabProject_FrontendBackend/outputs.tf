output "frontend_public_ip" {
  value = module.frontend.public_ip
}

output "backend_public_ips" {
  value = module.backend[*].public_ip
}

output "backend_private_ips" {
  value = module.backend[*].private_ip
}
