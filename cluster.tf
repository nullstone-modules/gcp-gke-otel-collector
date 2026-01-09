data "ns_connection" "cluster" {
  name     = "cluster"
  contract = "cluster/gcp/k8s"
}

locals {
  cluster_name           = data.ns_connection.cluster.outputs.cluster_name
  cluster_endpoint       = data.ns_connection.cluster.outputs.cluster_endpoint
  cluster_ca_certificate = data.ns_connection.cluster.outputs.cluster_ca_certificate
}

// See https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config#example-usage-configure-kubernetes-provider-with-oauth2-access-token
data "google_client_config" "provider" {}

provider "kubernetes" {
  host                   = "https://${local.cluster_endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
}
