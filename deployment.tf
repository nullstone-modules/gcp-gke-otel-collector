resource "kubernetes_deployment" "this" {
  metadata {
    name      = "collector"
    namespace = local.kubernetes_namespace
    labels    = local.k8s_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "nullstone.io/stack"          = local.stack_name
        "nullstone.io/env"            = local.env_name
        "nullstone.io/block"          = local.block_name
        "app.kubernetes.io/component" = "collector"
      }
    }

    template {
      metadata {
        labels = local.k8s_labels
      }

      spec {
        service_account_name = kubernetes_service_account.this.metadata[0].name

        container {
          name              = "collector"
          image_pull_policy = "IfNotPresent"
          image             = "us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:${var.collector_version}"

          args = [
            "--config=/conf/collector.yaml",
            "--feature-gates=exporter.googlemanagedprometheus.intToDouble,receiver.prometheusreceiver.RemoveStartTimeAdjustment"
          ]

          port {
            name           = "grpc"
            protocol       = "TCP"
            container_port = 4317
          }

          port {
            name           = "http"
            protocol       = "TCP"
            container_port = 4318
          }

          env {
            name  = "GOOGLE_CLOUD_PROJECT"
            value = local.project_id
          }

          env {
            name = "MY_POD_IP"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "status.podIP"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.cpu
              memory = var.memory
            }
            limits = {
              memory = var.memory_limit
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 13133
            }
          }

          volume_mount {
            name       = "collector-config"
            mount_path = "/conf"
            read_only  = true
          }
        }

        volume {
          name = "collector-config"
          config_map {
            name = kubernetes_config_map.this.metadata[0].name
          }
        }
      }
    }
  }
}
