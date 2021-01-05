output "ingress" {
  value = {
    load_balancer_ip = data.kubernetes_service.nginx-ingress-ingress-nginx-controller.load_balancer_ingress.0.ip
    fqdn             = local.fqdn
  }
}
