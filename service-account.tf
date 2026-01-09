resource "google_service_account" "this" {
  account_id   = local.resource_name
  display_name = "Service Account for Nullstone Block ${local.block_name}"
}

resource "kubernetes_service_account" "this" {
  metadata {
    namespace = local.kubernetes_namespace
    name      = local.block_name
    labels    = local.k8s_labels

    annotations = {
      // This indicates which GCP service account this kubernetes service account can impersonate
      "iam.gke.io/gcp-service-account" = google_service_account.this.email
    }
  }

  automount_service_account_token = true
}

// This allows the kubernetes service account <namespace>/<name> to impersonate a workload identity
resource "google_service_account_iam_member" "this_workload_identity" {
  service_account_id = google_service_account.this.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[${local.kubernetes_namespace}/${local.block_name}]"
}
resource "google_service_account_iam_member" "this_generate_token" {
  service_account_id = google_service_account.this.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[${local.kubernetes_namespace}/${local.block_name}]"
}

// Grant necessary roles to forward logs, traces, and metrics to GCP
resource "google_project_iam_member" "this_metric_writer" {
  project = local.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.this.email}"
}
resource "google_project_iam_member" "this_log_writer" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.this.email}"
}
resource "google_project_iam_member" "this_trace_agent" {
  project = local.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "kubernetes_cluster_role" "this" {
  metadata {
    name = local.resource_name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "namespaces", "nodes"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name = local.resource_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.this.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_service_account.this.metadata[0].namespace
  }
}
