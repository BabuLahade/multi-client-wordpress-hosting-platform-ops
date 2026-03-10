output "instance_ids" {
    value = aws_instance.app_instance[*].id
}
output "instance_public_ips" {
    value = aws_instance.app_instance[*].public_ip
}
output "public_ip" {
    value = aws_instance.app_instance[*].public_ip
}
output "private_ip" {
    value = aws_instance.app_instance[*].private_ip
}   
