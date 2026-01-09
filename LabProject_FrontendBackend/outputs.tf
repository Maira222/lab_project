output "frontend_public_ip" {
  description = "Public IP of frontend Nginx server"
  value       = aws_instance.frontend.public_ip
}

output "frontend_url" {
  description = "URL to access frontend"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "backend_public_ips" {
  description = "Public IPs of backend HTTPD servers"
  value       = [for b in aws_instance.backend : b.public_ip]
}

output "backend_private_ips" {
  description = "Private IPs of backend HTTPD servers"
  value       = [for b in aws_instance.backend : b.private_ip]
}

output "backend_urls" {
  description = "Direct URLs to backend servers"
  value       = [for b in aws_instance.backend : "http://${b.public_ip}"]
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web.id
}

output "test_commands" {
  description = "Commands to test the setup"
  value = <<-EOT
    # Test frontend (should alternate between backend 1 and 2):
    for i in {1..10}; do curl -s http://${aws_instance.frontend.public_ip} | grep "Backend server"; done
    
    # Test individual backends:
    curl http://${aws_instance.backend[0].public_ip}
    curl http://${aws_instance.backend[1].public_ip}
    curl http://${aws_instance.backend[2].public_ip}
    
    # Test backup failover (SSH to backends and stop httpd):
    ssh -i ${var.private_key} ec2-user@${aws_instance.backend[0].public_ip} "sudo systemctl stop httpd"
    ssh -i ${var.private_key} ec2-user@${aws_instance.backend[1].public_ip} "sudo systemctl stop httpd"
    # Now test frontend - should serve from backup (backend-2)
    curl http://${aws_instance.frontend.public_ip}
  EOT
}
