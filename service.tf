resource "kubernetes_service" "this" {
  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }

  metadata {
    namespace = local.kubernetes_namespace
    name      = "collector"
    labels    = local.k8s_labels
  }

  spec {
    type = "ClusterIP"

    selector = {
      "nullstone.io/stack"          = local.stack_name
      "nullstone.io/env"            = local.env_name
      "nullstone.io/block"          = local.block_name
      "app.kubernetes.io/component" = "collector"
    }

    internal_traffic_policy = "Cluster"

    port {
      name        = "grpc"
      protocol    = "TCP"
      port        = 4317
      target_port = 4317
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 4318
      target_port = 4318
    }
  }
}

locals {
  service_endpoint = "http://${kubernetes_service.this.metadata[0].name}.${kubernetes_service.this.metadata[0].namespace}"
}
