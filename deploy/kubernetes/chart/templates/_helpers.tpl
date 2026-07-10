{{/*
Chart name, truncated/sanitized for use as a Kubernetes object name component.
*/}}
{{- define "prismo-rpc-node.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name. Truncated to 63 chars because some Kubernetes name
fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prismo-rpc-node.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart name + version, for the chart label.
*/}}
{{- define "prismo-rpc-node.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "prismo-rpc-node.labels" -}}
helm.sh/chart: {{ include "prismo-rpc-node.chart" . }}
{{ include "prismo-rpc-node.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.network }}
prismo.network/network: {{ .Values.network }}
{{- end }}
{{- end -}}

{{/*
Selector labels — must be stable across releases (used in matchLabels).
*/}}
{{- define "prismo-rpc-node.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prismo-rpc-node.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Effective L1 RPC URL flag value: either .Values.config.l1RpcUrl or a Secret
reference. This helper only decides which template branch to take — the
actual value is projected as an env var elsewhere and referenced with
`$(L1_RPC_URL)` in the config args (cdk-erigon does not expand env vars
inside its --config file, so the URL is passed via a CLI flag argument that
IS shell/env-expanded by the container runtime's command line, see
statefulset.yaml).
*/}}
{{- define "prismo-rpc-node.hasL1RpcSecret" -}}
{{- if and .Values.config.l1RpcUrlSecret .Values.config.l1RpcUrlSecret.name .Values.config.l1RpcUrlSecret.key -}}
true
{{- end -}}
{{- end -}}
