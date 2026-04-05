output "valkey_endpoint" {
    value =aws_elasticache_replication_group.valkey_cluster.primary_endpoint_address
}