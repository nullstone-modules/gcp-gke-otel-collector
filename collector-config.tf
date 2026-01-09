resource "kubernetes_config_map" "this" {
  metadata {
    namespace = local.kubernetes_namespace
    name      = "collector-config"
  }

  data = {
    "collector.yaml" = file("${path.module}/collector.yml")
  }
}
