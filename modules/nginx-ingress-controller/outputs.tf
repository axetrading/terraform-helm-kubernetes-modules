output "nginx_ingress_controller" {
  description = "Nginx Ingress Controller Release Details"
  value = var.enabled ? {
    id        = helm_release.monitoring_nginx_ingress_controller[0].id
    name      = helm_release.monitoring_nginx_ingress_controller[0].name
    namespace = helm_release.monitoring_nginx_ingress_controller[0].namespace
  } : null
}
