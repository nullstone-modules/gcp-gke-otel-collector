variable "collector_version" {
  type        = string
  default     = "0.131.0"
  description = <<EOF
The version
EOF
}

variable "cpu" {
  type        = string
  default     = "200m"
  description = "The amount of CPU to request for each collector."
}

variable "memory" {
  type        = string
  default     = "128Mi"
  description = "The amount of memory to request for each collector."
}

variable "memory_limit" {
  type        = string
  default     = "256Mi"
  description = "The maximum amount of memory each collector can use."
}

variable "min_replicas" {
  type        = number
  default     = 1
  description = <<EOF
The minimum number of collector replicas to run.
Autoscaling is disabled if this equals "max_replicas".
When autoscaling is enabled, this adds replicas when cpu or memory exceed 80% utilization.
EOF
}

variable "max_replicas" {
  type        = number
  default     = 1
  description = <<EOF
The maximum number of collector replicas to run.
Autoscaling is disabled if this equals "min_replicas".
When autoscaling is enabled, this adds replicas when cpu or memory exceed 80% utilization.
EOF
}
