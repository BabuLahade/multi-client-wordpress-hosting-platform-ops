output "instance_id" {
    description = "The ID of the EC2 instance"
    value = aws_instance.wordpress.id
}
output "public_ip" {
    description = "The public IP address of the EC2 instance"
    value = aws_instance.wordpress.public_ip
}
output "security_group_id" {
    description = "The ID of the security group associated with the EC2 instance"
    value = aws_instance.wordpress.security_groups[0]
}