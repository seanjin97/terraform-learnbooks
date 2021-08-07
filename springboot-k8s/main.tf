terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "localhost_namespace" {
  metadata {
    name = var.env_name
  }
}

resource "kubernetes_secret" "docker_registry_secret" {
  metadata {
    name      = "docker-registry-secret"
    namespace = var.env_name
  }
  data = {
    ".dockerconfigjson" = file("${path.module}/secrets/docker-config.json")
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_storage_class" "main_storage_class" {
  metadata {
    name = "local-storage"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"
}
