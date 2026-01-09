output "kubernetes_namespace" {
  value       = local.kubernetes_namespace
  description = "string ||| The name of the created namespace containing only this OpenTelemetry collector"
}

output "grpc_endpoint" {
  value       = "${local.service_endpoint}:4317"
  description = "string ||| The endpoint URL to receive OpenTelemetry over gRPC"
}

output "http_endpoint" {
  value       = "${local.service_endpoint}:4318"
  description = "string ||| The endpoint URL to receive OpenTelemetry over HTTP"
}
