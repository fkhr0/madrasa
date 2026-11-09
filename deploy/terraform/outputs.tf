output "server_public_ip" {
  description = "Point the domain (DuckDNS) here."
  value       = oci_core_instance.server.public_ip
}

output "ssh" {
  value = "ssh ubuntu@${oci_core_instance.server.public_ip}"
}

output "backup_bucket_endpoint" {
  description = "BACKUP_S3_ENDPOINT in the server's .env"
  value       = "https://${data.oci_objectstorage_namespace.main.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}
