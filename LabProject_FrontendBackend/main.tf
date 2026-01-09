module "network" {
  source        = "./modules/subnet"
  vpc_cidr      = var.vpc_cidr_block
  subnet_cidr   = var.subnet_cidr_block
  az            = var.availability_zone
  env_prefix    = var.env_prefix
}

resource "aws_security_group" "web" {
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "frontend" {
  source = "./modules/webserver"

  name      = "lab-frontend"
  subnet_id = module.network.subnet_id
  sg_id     = aws_security_group.web.id
  key_name  = aws_key_pair.lab.key_name
}


module "backend" {
  source = "./modules/webserver"
  count  = 3

  name      = "lab-backend-${count.index}"
  subnet_id = module.network.subnet_id
  sg_id     = aws_security_group.web.id
  key_name  = aws_key_pair.lab.key_name
}

resource "aws_key_pair" "lab" {
  key_name   = "lab-key"
  public_key = file("~/.ssh/lab-key.pub")
}