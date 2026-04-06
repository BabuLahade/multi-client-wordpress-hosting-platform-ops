output "valkey_endpoint" {
    value =aws_elasticache_replication_group.valkey_cluster.primary_endpoint_address
}

# output "redis_endpoint" {
#     value =aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
# }