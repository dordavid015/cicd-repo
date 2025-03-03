output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}