resource "kubernetes_deployment_v1" "this" {
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
        service_account_name = kubernetes_service_account_v1.this.metadata[0].name

        container {
          name              = "collector"
          image_pull_policy = "IfNotPresent"
          image             = "us-docker.pkg.dev/cloud-ops-agents-artifacts/google-cloud-opentelemetry-collector/otelcol-google:${var.collector_version}"

          // Base config first, then one --config per extender-supplied file. The collector
          // deep-merges them in order; extender fragments add new map keys on top of the base.
          args = concat(
            [
              "--config=/conf/collector.yaml",
              "--feature-gates=exporter.googlemanagedprometheus.intToDouble,receiver.prometheusreceiver.RemoveStartTimeAdjustment",
            ],
            [for cm in local.extender_config_maps : "--config=${local.extender_mount_root}/${cm.filename}"],
          )

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

          // Mount each extender config map as a single file under local.extender_mount_root via
          // sub_path so multiple maps can share the directory without colliding.
          // Requires each config map to store its fragment under a data key equal to "filename".
          dynamic "volume_mount" {
            for_each = local.extender_config_maps_by_key
            content {
              name       = "extender-${volume_mount.key}"
              mount_path = "${local.extender_mount_root}/${volume_mount.value.filename}"
              sub_path   = volume_mount.value.filename
              read_only  = true
            }
          }
        }

        volume {
          name = "collector-config"
          config_map {
            name = kubernetes_config_map_v1.this.metadata[0].name
          }
        }

        dynamic "volume" {
          for_each = local.extender_config_maps_by_key
          content {
            name = "extender-${volume.key}"
            config_map {
              name = volume.value.configMapName
            }
          }
        }
      }
    }
  }

  lifecycle {
    // When an extender is connected, it must create its config maps in the same namespace this
    // collector deploys into, otherwise the config map volumes cannot mount.
    precondition {
      condition     = !local.extender_connected || local.extender_namespace == local.kubernetes_namespace
      error_message = "The 'extender' connection must target the same cluster-namespace as this collector. collector namespace=\"${local.kubernetes_namespace}\", extender namespace=\"${coalesce(local.extender_namespace, "<none>")}\". Wire both blocks to the same cluster-namespace block."
    }
  }
}
