# Nicholas S. Castellano
# Released in the public domain 2021-01-04 under the CC0 1.0 Universal license
# https://creativecommons.org/publicdomain/zero/1.0/deed.en

# Terraform deployment of an AKS cluster with TLS-enabled ingress and
# a demo application

# This is intended to be a more-or-less direct translation of the
# Microsoft demo deployment described at:
# https://docs.microsoft.com/en-us/azure/aks/ingress-tls

terraform {
  required_version = ">= 0.13.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.41.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.13.3"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.9.4"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0.1"
    }
  }
}

provider "azurerm" {
  features {
  }
}

locals {
  letsencrypt-acme-api = {
    production = "https://acme-v02.api.letsencrypt.org/directory"
    staging    = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }

  acme-server = local.letsencrypt-acme-api[var.letsencrypt-acme-api]
  fqdn        = "${var.ingress-subdomain-name}.${var.zone-name}"
}

resource "azurerm_resource_group" "rg-aks" {
  name     = var.aks-rg-name
  location = var.aks-location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks-name
  location            = azurerm_resource_group.rg-aks.location
  resource_group_name = azurerm_resource_group.rg-aks.name
  dns_prefix          = var.aks-name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
  }
}

provider "kubernetes" {
  load_config_file       = "false"
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  username               = azurerm_kubernetes_cluster.aks.kube_config.0.username
  password               = azurerm_kubernetes_cluster.aks.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

provider "kubectl" {
  load_config_file       = "false"
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  username               = azurerm_kubernetes_cluster.aks.kube_config.0.username
  password               = azurerm_kubernetes_cluster.aks.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    username               = azurerm_kubernetes_cluster.aks.kube_config.0.username
    password               = azurerm_kubernetes_cluster.aks.kube_config.0.password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

## Create a namespace for your ingress resources
#kubectl create namespace ingress-basic

resource "kubernetes_namespace" "ingress-basic" {
  metadata {
    name = "ingress-basic"

    ## Label the ingress-basic namespace to disable resource validation
    #kubectl label namespace ingress-basic cert-manager.io/disable-validation=true
    labels = {
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

## Add the ingress-nginx repository
#helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
#
## Use Helm to deploy an NGINX ingress controller
#helm install nginx-ingress ingress-nginx/ingress-nginx \
#    --namespace ingress-basic \
#    --set controller.replicaCount=2 \
#    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
#    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

resource "helm_release" "nginx-ingress" {
  namespace  = kubernetes_namespace.ingress-basic.metadata.0.name
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "3.16.1"

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "defaultBackend.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
}

# kubectl --namespace ingress-basic get services -o wide -w nginx-ingress-ingress-nginx-controller
data "kubernetes_service" "nginx-ingress-ingress-nginx-controller" {
  metadata {
    namespace = helm_release.nginx-ingress.namespace
    name      = "nginx-ingress-ingress-nginx-controller"
  }
}

#az network dns record-set a add-record \
#    --resource-group myResourceGroup \
#    --zone-name MY_CUSTOM_DOMAIN \
#    --record-set-name * \
#    --ipv4-address MY_EXTERNAL_IP

resource "azurerm_dns_a_record" "lb-dns" {
  name                = var.ingress-subdomain-name
  zone_name           = var.zone-name
  resource_group_name = var.zone-rg
  ttl                 = 300
  records             = [data.kubernetes_service.nginx-ingress-ingress-nginx-controller.load_balancer_ingress.0.ip]
}

resource "azurerm_dns_a_record" "lb-dns-wildcard" {
  name                = "*.${var.ingress-subdomain-name}"
  zone_name           = var.zone-name
  resource_group_name = var.zone-rg
  ttl                 = 300
  records             = [data.kubernetes_service.nginx-ingress-ingress-nginx-controller.load_balancer_ingress.0.ip]
}

## Add the Jetstack Helm repository
#helm repo add jetstack https://charts.jetstack.io
#
## Update your local Helm chart repository cache
#helm repo update
#
## Install the cert-manager Helm chart
#helm install \
#  cert-manager \
#  --namespace ingress-basic \
#  --version v0.16.1 \
#  --set installCRDs=true \
#  --set nodeSelector."beta\.kubernetes\.io/os"=linux \
#  jetstack/cert-manager

resource "helm_release" "cert-manager" {
  namespace  = kubernetes_namespace.ingress-basic.metadata.0.name
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v0.16.1"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
}

resource "kubectl_manifest" "cluster-issuer" {
  depends_on = [
    helm_release.cert-manager,
  ]

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: ${local.acme-server}
    email: ${var.email}
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
YAML
}

#kubectl apply -f aks-helloworld-one.yaml --namespace ingress-basic
#kubectl apply -f aks-helloworld-two.yaml --namespace ingress-basic

locals {
  helloworld-deployments = {
    one = {
      title = "Welcome to Azure Kubernetes Service (AKS)"
    }
    two = {
      title = "AKS Ingress Demo"
    }
  }
}

resource "kubernetes_deployment" "aks-helloworld" {
  for_each = local.helloworld-deployments

  metadata {
    namespace = "ingress-basic"
    name      = "aks-helloworld-${each.key}"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "aks-helloworld-${each.key}"
      }
    }

    template {
      metadata {
        labels = {
          app = "aks-helloworld-${each.key}"
        }
      }

      spec {
        container {
          name  = "aks-helloworld-${each.key}"
          image = "mcr.microsoft.com/azuredocs/aks-helloworld:v1"

          port {
            container_port = 80
          }

          env {
            name  = "TITLE"
            value = each.value.title
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "hello-world-service" {
  for_each = kubernetes_deployment.aks-helloworld

  metadata {
    namespace = each.value.metadata.0.namespace
    name      = each.value.metadata.0.name
  }

  spec {
    type = "ClusterIP"

    port {
      port = 80
    }

    selector = {
      app = each.value.spec.0.template.0.metadata.0.labels.app
    }
  }
}

#kubectl apply -f hello-world-ingress.yaml --namespace ingress-basic

resource "kubernetes_ingress" "hello-world-ingress" {
  metadata {
    namespace = "ingress-basic"
    name      = "hello-world-ingress"
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "cert-manager.io/cluster-issuer"             = "letsencrypt"
    }
  }

  spec {
    tls {
      hosts       = [local.fqdn]
      secret_name = "tls-secret"
    }

    rule {
      host = local.fqdn
      http {
        path {
          backend {
            service_name = "aks-helloworld-one"
            service_port = 80
          }

          path = "/hello-world-one(/|$)(.*)"
        }

        path {
          backend {
            service_name = "aks-helloworld-two"
            service_port = 80
          }

          path = "/hello-world-two(/|$)(.*)"
        }

        path {
          backend {
            service_name = "aks-helloworld-one"
            service_port = 80
          }

          path = "/(.*)"
        }
      }
    }
  }
}

resource "kubernetes_ingress" "hello-world-ingress-static" {
  metadata {
    namespace = "ingress-basic"
    name      = "hello-world-ingress-static"

    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/static/$2"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
      "cert-manager.io/cluster-issuer"             = "letsencrypt"
    }
  }

  spec {
    tls {
      hosts       = [local.fqdn]
      secret_name = "tls-secret"
    }

    rule {
      host = local.fqdn

      http {
        path {
          backend {
            service_name = "aks-helloworld-one"
            service_port = 80
          }

          path = "/static(/|$)(.*)"
        }
      }
    }
  }
}
