/*
  * Terraform module to deploy Loki Stack on Kubernetes cluster.
  More details about Loki Stack: https://grafana.com/oss/loki/
  This module will create:
  - Loki Stack namespace
  - Loki Stack helm release
  - Loki Stack IAM role
  - Loki Stack S3 bucket
  - Loki Stack S3 bucket policy
  - Loki Stack S3 bucket lifecycle rule
*/

locals {
  bucket_name = var.create_bucket ? aws_s3_bucket.loki[0].id : var.bucket_name
}

resource "helm_release" "loki" {
  count = var.enabled ? 1 : 0

  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_version
  namespace  = "monitoring"

  set {
    name  = "loki.fullnameOverride"
    value = "loki"
  }

  set {
    name  = "promtail.enabled"
    value = var.promtail_enabled
  }

  set {
    name  = "promtail.fullnameOverride"
    value = "promtail"
    type  = "string"
  }

  dynamic "set" {
    for_each = var.create_role ? [aws_iam_role.this[0].arn] : [var.role_arn]
    content {
      name  = "loki.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = set.value
      type  = "string"
    }
  }

  set {
    name  = "loki.storageConfig.aws.s3.bucketName"
    value = "s3://${var.region}/${local.bucket_name}"
  }
}

