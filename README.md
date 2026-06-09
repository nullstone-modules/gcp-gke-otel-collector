# gcp-gke-otel-collector

Launches an OpenTelemetry collector on GKE that relays logs, traces, and metrics to Cloud Logging, Cloud Trace, and Cloud Monitoring.

This is based on the Kustomize from the official Google repo: https://github.com/GoogleCloudPlatform/otlp-k8s-ingest.

## Connections

| Name                | Contract                        | Required  | Purpose                                                                  |
|---------------------|---------------------------------|-----------|--------------------------------------------------------------------------|
| `cluster-namespace` | `cluster-namespace/gcp/k8s:gke` | yes       | The GKE cluster + namespace the collector deploys into.                  |
| `extender`          | `datastore/gcp/otel-extender`   | no        | Registers additional collector config files (extra exporters/pipelines). |

The collector runs in the namespace provided by the `cluster-namespace` connection (it no longer
creates its own). Wire it to a dedicated namespace block if you want the collector isolated.

## Extending the collector (the `extender` connection)

To send telemetry to additional destinations (e.g. Langfuse, Datadog, Honeycomb) **without forking
this module**, connect an `extender` block. The extender creates one or more Kubernetes config maps
holding OTEL config fragments and reports them through its outputs; this module mounts each fragment
and passes it to the collector as an extra `--config`.

### Extender output contract

The extender block must expose these outputs:

```hcl
# The config files to merge into the collector, in addition to the base config.
output "collector-config-maps" {
  value = list(object({
    filename      = string  # file name the fragment is mounted as, and the config map data key
    configMapName = string  # name of the Kubernetes config map holding the fragment
  }))
}

# The namespace the extender created its config maps in (from its own cluster-namespace connection).
# Used by this collector to validate both blocks target the same namespace.
output "kubernetes_namespace" {
  value = string
}
```

Requirements:

- **Same namespace.** The extender must connect to the **same `cluster-namespace`** block as this
  collector, so its config maps live where the collector pod can mount them. The collector enforces
  this at plan time (`kubernetes_namespace` must match) and fails with a clear message otherwise.
- **Data key == `filename`.** Each config map must store its fragment under a data key equal to the
  `filename` reported for it (the file is mounted via `subPath`).

### Writing a config fragment

The OTEL collector deep-merges multiple `--config` files: **maps merge recursively, but lists are
replaced, not appended.** So a fragment must contribute **new map keys** — its own exporter,
processor(s), and a new `traces/<name>` pipeline — rather than appending to the base `traces`
pipeline's exporter list (which would clobber the Google Cloud Trace exporter).

Example fragment that fans GenAI traces out to Langfuse while Cloud Trace keeps receiving everything:

```yaml
# langfuse.yaml  (stored under config-map data key "langfuse.yaml")
exporters:
  otlphttp/langfuse:
    endpoint: https://cloud.langfuse.com/api/public/otel
    headers:
      Authorization: "Basic ${env:LANGFUSE_AUTH}"
processors:
  filter/langfuse:
    error_mode: ignore
    traces:
      span:
        - 'attributes["gen_ai.system"] == nil'   # drop non-GenAI spans
service:
  pipelines:
    traces/langfuse:                # NEW pipeline key -> merges cleanly, no list conflict
      receivers: [otlp]             # shares the base otlp receiver by reference
      processors: [k8sattributes, memory_limiter, batch, filter/langfuse]
      exporters: [otlphttp/langfuse]
```

When no `extender` is connected, the deployment is unchanged.
