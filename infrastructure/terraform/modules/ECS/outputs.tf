output "cluster_name" {
    value = aws_ecs_cluster.clients.name
}
output "service_name" {
    value = {
        for k , v in aws_ecs_service.clients : k=>v.name
    }
}