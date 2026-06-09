// An optional "extender" block can register additional collector config files (e.g. an exporter
// plus a filtered traces/<sink> pipeline that forwards to Langfuse, Datadog, etc.) without forking
// this module. The extender creates the config maps in the shared namespace and reports them here;
// the deployment mounts each one and passes it as an additional --config to the collector.
//
// The OTEL collector deep-merges multiple --config files: maps merge, but lists are *replaced*.
// Each fragment must therefore contribute new map keys (its own exporter/processor/pipeline) rather
// than appending to the base traces pipeline's exporter list.
data "ns_connection" "extender" {
  name     = "extender"
  contract = "datastore/gcp/otel-extender"
  optional = true
}

locals {
  // Presence flag: the connection is wired iff its config-maps output resolves (even to []).
  extender_connected = try(data.ns_connection.extender.outputs["collector-config-maps"], null) != null

  // list(object({ filename = string, configMapName = string })); [] when not connected.
  // Each config map must store its fragment under a data key equal to "filename".
  extender_config_maps = try(data.ns_connection.extender.outputs["collector-config-maps"], [])

  // Keyed by index so dynamic blocks get stable, unique, DNS-safe volume names even when two
  // config maps share a filename.
  extender_config_maps_by_key = { for idx, cm in local.extender_config_maps : tostring(idx) => cm }

  extender_mount_root = "/conf/extender"

  // The namespace the extender created its config maps in (from its own cluster-namespace
  // connection). Used to validate it matches this collector's namespace. null when absent.
  extender_namespace = try(data.ns_connection.extender.outputs["kubernetes_namespace"], null)
}
