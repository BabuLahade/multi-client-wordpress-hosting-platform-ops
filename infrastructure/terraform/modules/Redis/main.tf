resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = values(var.private_db_subnet_ids)
}
resource "aws_elasticache_subnet_group" "valkey_subnet_group" {
    name = "${var.project_name}-valkey-subnet-group"
    subnet_ids =values(var.private_db_subnet_ids)
}

resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "${var.project_name}-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [var.redis_security_group_id]
  tags = {
    Name = "${var.project_name}-redis-cluster"
  }
}
resource "aws_elasticache_replication_group" "valkey_cluster" {
    replication_group_id = "${var.project_name}-valkey-cluster"
    description = "valkey object cache for wordpress"
    engine = "valkey"
    engine_version = "7.2"
    parameter_group_name = "default.valkey7"

    node_type = "cache.t4g,micro"
    num_cache_clusters = 1

    port = 6379
    subnet_group_name = aws_elasticache_subnet_group.valkey_subnet_group
    security_group_ids = [var.redis_security_group_id]
}