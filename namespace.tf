resource "kubernetes_namespace" "this" {
  metadata {
    name = local.resource_name
  }
}

locals {
  kubernetes_namespace = kubernetes_namespace.this.metadata[0].name
}
