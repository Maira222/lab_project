resource "aws_instance" "this" {
  ami           = "ami-0fcb14c72c80bdef2"
  instance_type = "t2.micro"

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name

  tags = {
    Name = var.name
  }
}
