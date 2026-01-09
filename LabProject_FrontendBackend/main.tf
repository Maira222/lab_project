terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to get current public IP
data "http" "my_ip" {
  url = "https://icanhazip.com"
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env_prefix}-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.env_prefix}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web" {
  name        = "${var.env_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # SSH from my IP only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
    description = "SSH from my IP"
  }

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # Allow all traffic within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
    description = "All traffic from VPC"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.env_prefix}-web-sg"
  }
}

# Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "${var.env_prefix}-deployer-key"
  public_key = file(var.public_key)
}

# Frontend EC2 Instance
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "${var.env_prefix}-frontend"
    Type = "frontend"
  }

  # Wait for instance to be ready
  provisioner "remote-exec" {
    inline = ["echo 'Instance ready'"]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key)
      host        = self.public_ip
      timeout     = "5m"
    }
  }
}

# Backend EC2 Instances
resource "aws_instance" "backend" {
  count = 3

  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "${var.env_prefix}-backend-${count.index}"
    Type = "backend"
  }

  # Wait for instance to be ready
  provisioner "remote-exec" {
    inline = ["echo 'Instance ready'"]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key)
      host        = self.public_ip
      timeout     = "5m"
    }
  }
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/hosts.tpl", {
    frontend_public_ip     = aws_instance.frontend.public_ip
    backend_public_ips     = [for b in aws_instance.backend : b.public_ip]
    backend_private_ips    = [for b in aws_instance.backend : b.private_ip]
    ansible_user           = var.ansible_user
    ansible_ssh_private_key = var.private_key
  })
  filename = "${path.module}/ansible/inventory/hosts"

  depends_on = [
    aws_instance.frontend,
    aws_instance.backend
  ]
}

# Generate extra vars file for Ansible
resource "local_file" "ansible_extra_vars" {
  content = templatefile("${path.module}/templates/extra_vars.tpl", {
    backend_private_ips = [for b in aws_instance.backend : b.private_ip]
  })
  filename = "${path.module}/ansible/extra_vars.yml"

  depends_on = [
    aws_instance.backend
  ]
}

# Run Ansible after infrastructure is ready
resource "null_resource" "ansible_config" {
  triggers = {
    frontend_ip = aws_instance.frontend.public_ip
    backend_ips = join(",", [for b in aws_instance.backend : b.public_ip])
    always_run  = timestamp()
  }

  depends_on = [
    aws_instance.frontend,
    aws_instance.backend,
    local_file.ansible_inventory,
    local_file.ansible_extra_vars
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting 30 seconds for instances to be fully ready..."
      sleep 30
      cd ${path.module}/ansible
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
        -i inventory/hosts \
        -e @extra_vars.yml \
        playbooks/site.yaml
    EOT
  }
}
