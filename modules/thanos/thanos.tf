/*
This terraform module will install Thanos and its dependencies into the cluster using Helm. 
It will also create an S3 bucket for Thanos to use as an object store. 
*/

locals {
  thanos_bucket_name = var.create_bucket ? try(aws_s3_bucket.thanos[0].id, var.existing_bucket_name) : var.existing_bucket_name
  config_file = var.enabled ? templatefile("${path.module}/configs/objstore.tpl", {
    thanos_objstore_bucket   = local.thanos_bucket_name,
    thanos_objstore_region   = var.thanos_bucket_region,
    thanos_objstore_endpoint = var.thanos_objstore_endpoint,
  }) : ""
}


resource "helm_release" "thanos" {
  count = var.enabled ? 1 : 0

  name       = "thanos"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "thanos"
  version    = var.thanos_version
  namespace  = "monitoring"

  dynamic "set" {
    for_each = var.create_role ? [true] : []
    content {
      name  = "serviceAccount.create"
      value = set.value
    }
  }

  dynamic "set" {
    for_each = var.create_role ? [aws_iam_role.this[0].arn] : [var.role_arn]
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
      type  = "string"
    }
  }

  set {
    name  = "query.enabled"
    value = true
  }

  set {
    name  = "query.autoscaling.enabled"
    value = var.thanos_query_autoscaling_enabled
  }

  set {
    name  = "query.autoscaling.minReplicas"
    value = var.thanos_query_autoscaling_min_replicas
  }

  set {
    name  = "query.autoscaling.maxReplicas"
    value = var.thanos_query_autoscaling_max_replicas
  }

  set {
    name  = "query.autoscaling.targetCPU"
    value = var.thanos_query_autoscaling_target_cpu_utilization_percentage
  }

  set {
    name  = "query.autoscaling.targetMemory"
    value = var.thanos_query_autoscaling_target_memory_utilization_percentage
  }

  set {
    name  = "query.resources.requests.cpu"
    value = var.thanos_query_resources_requests_cpu
  }

  set {
    name  = "query.resources.requests.memory"
    value = var.thanos_query_resources_requests_memory
  }

  set {
    name  = "query.resources.limits.memory"
    value = var.thanos_query_resources_limits_memory
  }


  set {
    name  = "compactor.enabled"
    value = true
  }

  set {
    name  = "compactor.retentionResolutionRaw"
    value = var.thanos_compactor_retention_resolution_raw
  }

  set {
    name  = "compactor.retentionResolution5m"
    value = var.thanos_compactor_retention_resolution_5m
  }

  set {
    name  = "compactor.retentionResolution1h"
    value = var.thanos_compactor_retention_resolution_1h
  }

  dynamic "set" {
    for_each = var.create_role ? [aws_iam_role.this[0].arn] : [var.role_arn]
    content {
      name  = "compactor.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
      type  = "string"
    }
  }

  set {
    name  = "storegateway.enabled"
    value = true
  }

  set {
    name  = "storegateway.replicaCount"
    value = var.thanos_storegateway_replica_count
  }

  dynamic "set" {
    for_each = var.create_role ? [aws_iam_role.this[0].arn] : [var.role_arn]
    content {
      name  = "storegateway.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
      type  = "string"
    }
  }

  set {
    name  = "ruler.enabled"
    value = false
  }

  set {
    name  = "objstoreConfig"
    value = local.config_file
  }

  dynamic "set_list" {
    for_each = var.thanos_stores_endpoints != null ? [var.thanos_stores_endpoints] : []
    content {
      name  = "query.stores"
      value = set_list.value
    }
  }

  set {
    name  = "receive.enabled"
    value = var.thanos_receiver_enabled
  }

  set {
    name  = "receive.tsdbRetention"
    value = "2d"
  }



}

resource "helm_release" "thanos_targetgroupbinding_crds" {
  count     = var.enabled && var.thanos_gateway_enabled ? 1 : 0
  name      = "thanos-gateway"
  chart     = "${path.module}/../helm-template/crds"
  namespace = "monitoring"

  set {
    name  = "fullnameOverride"
    value = "thanos-gateway"
  }

  set {
    name  = "targetGroupBinding.service.name"
    value = "thanos-query"
  }

  set {
    name  = "targetGroupBinding.port"
    value = "9090"
  }

  set {
    name  = "targetGroupBinding.targetGroupARN"
    value = var.thanos_gateway_target_group_arn
  }

  depends_on = [
    helm_release.thanos
  ]
}

resource "helm_release" "thanos_receiver_targetgroupbinding_crds" {
  count     = var.enabled && var.thanos_receiver_enabled ? 1 : 0
  name      = "thanos-receiver"
  chart     = "${path.module}/../helm-template/crds"
  namespace = "monitoring"

  set {
    name  = "fullnameOverride"
    value = "thanos-receiver"
  }

  set {
    name  = "targetGroupBinding.service.name"
    value = "thanos-receive"
  }

  set {
    name  = "targetGroupBinding.port"
    value = var.thanos_receiver_remote_write_port
  }

  set {
    name  = "targetGroupBinding.targetGroupARN"
    value = var.thanos_receiver_target_group_arn
  }

  depends_on = [
    helm_release.thanos
  ]
}

