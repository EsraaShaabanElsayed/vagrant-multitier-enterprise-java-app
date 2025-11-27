
# ============================================================================
# Outputs
# ============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}



output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "memcached_endpoint" {
  description = "ElastiCache Memcached endpoint"
  value       = "${aws_elasticache_cluster.memcached.cluster_address}:11211"
}

output "rabbitmq_endpoint" {
  description = "AmazonMQ RabbitMQ endpoint (AMQPS)"
  value       = aws_mq_broker.rabbitmq.instances[0].endpoints[0]
}

output "rabbitmq_console_url" {
  description = "RabbitMQ Management Console URL"
  value       = aws_mq_broker.rabbitmq.instances[0].console_url
}



output "application_properties" {
  description = "Generated application.properties content"
  value = templatefile("${path.module}/application.properties.tpl", {
    db_endpoint        = aws_db_instance.mysql.endpoint
    db_name            = var.db_name
    db_username        = var.db_username
    db_password        = var.db_password
    memcached_endpoint = aws_elasticache_cluster.memcached.cluster_address
    rabbitmq_endpoint  = replace(aws_mq_broker.rabbitmq.instances[0].endpoints[0], "amqps://", "")
    rabbitmq_username  = var.rabbitmq_username
    rabbitmq_password  = var.rabbitmq_password
  })
  sensitive = true
}
