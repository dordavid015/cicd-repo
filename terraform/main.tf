provider "aws" {
  region = "eu-west-1"
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-terraform-key"  # שם המפתח שיופיע ב-AWS
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.key.private_key_pem
  filename = "${path.module}/private_key.pem"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0694d931cee176e7d"  # Ubuntu 22.04 LTS
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "ApplicationServer"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Security group for application server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

