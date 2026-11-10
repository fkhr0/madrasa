output "server_public_ip" {
  description = "Point the domain (DuckDNS) here."
  value       = aws_eip.server.public_ip
}

output "ssh" {
  value = "ssh ubuntu@${aws_eip.server.public_ip}"
}

output "backup_bucket" {
  description = "BACKUP_S3_BUCKET in the server's .env (no keys: the server's role)"
  value       = aws_s3_bucket.backups.bucket
}
