/*
  This block deploys Prometheus server using the Helm provider in Terraform. 
  The `helm_release` resource creates a Kubernetes deployment for the Prometheus server, with the specified chart version and configuration options. 
  The Prometheus server is used for monitoring and alerting in Kubernetes clusters.
*/

locals {
  prometheus_config_files = [
    templatefile("${path.module}/config/prometheus.tpl", {
      thanos_sidecar_secret_name = var.thanos_sidecar_secret_name
    }),
    var.alertmanager_enabled ? templatefile("${path.module}/config/alertmanager.tpl", {
      slack_api_url         = var.slack_api_url,
      slack_channel         = var.slack_channel,
      pagerduty_url         = var.pagerduty_url,
      pagerduty_service_key = var.pagerduty_service_key
    }) : null
  ]
  prometheus_config = compact(local.prometheus_config_files)
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.enabled ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version
  namespace  = "monitoring"
  values     = local.prometheus_config

  set {
    name  = "defaultRules.create"
    value = var.enable_default_prometheus_rules
  }

  dynamic "set" {
    for_each = var.enable_default_prometheus_rules && var.prometheus_default_rules != null ? var.prometheus_default_rules : {}
    content {
      name  = "defaultRules.rules.${set.key}"
      value = set.value
    }
  }

  set {
    name  = "grafana.enabled"
    value = false
  }

  set {
    name  = "prometheus.serviceAccount.name"
    value = var.create_service_account ? "prometheus-sa" : null
    type  = "string"
  }

  dynamic "set" {
    for_each = var.create_role && var.create_service_account ? [aws_iam_role.this[0].arn] : [var.role_arn]
    content {
      name  = "prometheus.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
      type  = "string"
    }
  }

  set {
    name  = "prometheus.prometheusSpec.scrapeInterval"
    value = var.prometheus_scrape_interval
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_tsdb_retention
  }

  set {
    name  = "prometheus.prometheusSpec.scrapeTimeout"
    value = var.prometheus_scrape_timeout
  }

  set {
    name  = "prometheus.thanosService.enabled"
    value = true
  }

  set {
    name  = "prometheus.thanosServiceMonitor.enabled"
    value = true
  }

  set {
    name  = "prometheus.prometheusSpec.externalLabels.cluster"
    value = var.cluster_name
  }

  set {
    name  = "alertmanager.enabled"
    value = var.alertmanager_enabled
  }

  dynamic "set" {
    for_each = var.alertmanager_enabled ? [true] : [false]
    content {
      name  = "alertmanager.alertmanagerSpec.logLevel"
      value = var.alertmanager_log_level
    }
  }

  dynamic "set" {
    for_each = var.prometheus_external_url != null && var.alertmanager_enabled ? [var.prometheus_external_url] : []
    content {
      name  = "prometheus.prometheusSpec.externalUrl"
      value = set.value
    }
  }

  dynamic "set" {
    for_each = var.alertmanager_external_url != null && var.alertmanager_enabled ? [var.alertmanager_external_url] : []
    content {
      name  = "alertmanager.alertmanagerSpec.externalUrl"
      value = set.value
    }
  }

  set {
    name  = "prometheus.thanosServiceExternal.enabled"
    value = var.enable_thanos_external_service
  }

  dynamic "set" {
    for_each = var.enable_thanos_external_service ? [true] : []
    content {
      name  = "prometheus.thanosServiceExternal.type"
      value = "NodePort"
    }

  }
}


resource "helm_release" "prometheus_targetgroupbinding_crds" {
  count     = var.enabled && var.prometheus_gateway_enabled ? 1 : 0
  name      = "prometheus-server-gateway"
  chart     = "${path.module}/../helm-template/crds"
  namespace = "monitoring"

  set {
    name  = "fullnameOverride"
    value = "prometheus-server-gateway"
  }

  set {
    name  = "targetGroupBinding.service.name"
    value = "prometheus-kube-prometheus-prometheus"
  }

  set {
    name  = "targetGroupBinding.port"
    value = "9090"
  }

  set {
    name  = "targetGroupBinding.targetGroupARN"
    value = var.prometheus_gateway_target_group_arn
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

resource "helm_release" "alertmanager_targetgroupbinding_crds" {
  count     = var.enabled && var.alertmanager_enabled ? 1 : 0
  name      = "alertmanager-gateway"
  chart     = "${path.module}/../helm-template/crds"
  namespace = "monitoring"

  set {
    name  = "fullnameOverride"
    value = "alertmanager-gateway"
  }

  set {
    name  = "targetGroupBinding.service.name"
    value = "prometheus-kube-prometheus-alertmanager"
  }

  set {
    name  = "targetGroupBinding.port"
    value = "9093"
  }

  set {
    name  = "targetGroupBinding.targetGroupARN"
    value = var.alertmanager_target_group_arn
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

resource "helm_release" "thanos_sidecar_targetgroupbinding_crds" {
  count     = var.enabled && var.thanos_sidecar_enabled ? 1 : 0
  name      = "thanos-sidecar-gateway"
  chart     = "${path.module}/../helm-template/crds"
  namespace = "monitoring"

  set {
    name  = "fullnameOverride"
    value = "thanos-sidecar-gateway"
  }

  set {
    name  = "targetGroupBinding.service.name"
    value = var.enable_thanos_external_service ? "prometheus-kube-prometheus-thanos-external" : "prometheus-kube-prometheus-thanos-discovery"
  }

  set {
    name  = "targetGroupBinding.port"
    value = "10901"
  }

  set {
    name  = "targetGroupBinding.targetGroupARN"
    value = var.thanos_sidecar_target_group_arn
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}
