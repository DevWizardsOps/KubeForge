{{/*
Helpers do chart whoami. Definem nome e labels reutilizados pelos templates,
para não repetir a mesma expressão em cada arquivo.
*/}}

{{/* Nome base do release (usa o nome do release do Helm). */}}
{{- define "whoami.fullname" -}}
{{- .Release.Name }}
{{- end -}}

{{/* Labels padrão recomendados pelo Kubernetes/Helm. */}}
{{- define "whoami.labels" -}}
app.kubernetes.io/name: whoami
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: whoami-{{ .Chart.Version }}
{{- end -}}

{{/* Selector labels (subconjunto imutável — não inclui versão). */}}
{{- define "whoami.selectorLabels" -}}
app.kubernetes.io/name: whoami
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
