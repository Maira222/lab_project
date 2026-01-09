locals {
  # Get current public IP for security group SSH access
  my_ip = "${chomp(data.http.my_ip.response_body)}/32"
}
