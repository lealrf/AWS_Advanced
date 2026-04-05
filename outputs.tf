output "finguard_api_url" {
  description = "The URL to access the running FinGuard Container via Nginx Proxy"
  value       = "http://${aws_instance.app_server.public_ip}/health"
}

output "secure_s3_bucket" {
  description = "The KMS-Encrypted S3 bucket for transaction logs"
  value       = aws_s3_bucket.tx_logs.id
}