variable "csvtodb_data_mount_path" {
  type = string
}

variable "csvtodb_logs_mount_path" {
  type = string
}
resource "kubernetes_config_map" "csvtodb_config" {
  metadata {
    name      = "csvtodb-config"
    namespace = var.env_name
  }
  data = {
    "localhost-config.json" = jsonencode({
      "csvtodb.config.directory" : "csvtodb/Data",
      "csvtodb.config.interval" : "3600",
      "csvtodb.config.timeOffsetToRunTask" : "1",
      "csvtodb.config.generalApi" : "http://hapi-general-server-service:3000/api/general/v1/bulk/",
      "csvtodb.config.verticalApi" : "http://hapi-vertical-server-service:3001/api/vertical/v1/bulk/",
      "csvtodb.config.validVerticalFolders" : "escalator,door",
      "csvtodb.config.validGeneralFolders" : "controller_device_data"
    })
  }
}
resource "kubernetes_deployment" "csvtodb_deployment" {
  metadata {
    name      = "csvtodb"
    namespace = var.env_name
    labels = {
      app = "csvtodb"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app  = "csvtodb"
        role = "backend"
        env : var.env_name
      }
    }
    template {
      metadata {
        labels = {
          app  = "csvtodb"
          role = "backend"
          env : var.env_name
        }
      }
      spec {
        container {
          image = "ghcr.io/seanjin97/csvtodb:latest"
          name  = "csvtodb"
          port {
            name           = "server-port"
            container_port = 8080
          }
          env {
            name = "SPRING_APPLICATION_JSON"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.csvtodb_config.metadata.0.name
                key  = keys(kubernetes_config_map.csvtodb_config.data).0
              }
            }
          }
          volume_mount {
            mount_path = var.csvtodb_data_mount_path
            name       = "data-volume"
          }
          volume_mount {
            mount_path = var.csvtodb_logs_mount_path
            name       = "logging-volume"
          }
        }
        volume {
          name = "data-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.csvtodb_data_pvc.metadata.0.name
          }
        }
        volume {
          name = "logging-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.csvtodb_logs_pvc.metadata.0.name
          }
        }
        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.csvtodb_config.metadata.0.name
          }
        }
        image_pull_secrets {
          name = kubernetes_secret.docker_registry_secret.metadata.0.name
        }
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/hostname"
                  operator = "In"
                  values   = ["k3d-terra-k8s-agent-0"]
                }
              }
            }
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "csvtodb_service" {
  metadata {
    name      = "csvtodb-service"
    namespace = var.env_name
    labels    = kubernetes_deployment.csvtodb_deployment.metadata.0.labels
  }
  spec {
    selector = {
      app  = kubernetes_deployment.csvtodb_deployment.spec.0.template.0.metadata.0.labels.app
      role = kubernetes_deployment.csvtodb_deployment.spec.0.template.0.metadata.0.labels.role
      env  = kubernetes_deployment.csvtodb_deployment.spec.0.template.0.metadata.0.labels.env
    }
    type = "ClusterIP"
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_persistent_volume" "csvtodb_data_pv" {
  metadata {
    name = "csvtodb-data-pv"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    volume_mode                      = "Filesystem"
    storage_class_name               = "local-storage"
    persistent_volume_source {
      local {
        path = "/Data"
      }
    }
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["k3d-terra-k8s-agent-0"]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume" "csvtodb_logs_pv" {
  metadata {
    name = "csvtodb-logs-pv"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    volume_mode                      = "Filesystem"
    storage_class_name               = "local-storage"
    persistent_volume_source {
      local {
        path = "/logging/CSVtoDBlogs"
      }
    }
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "kubernetes.io/hostname"
            operator = "In"
            values   = ["k3d-terra-k8s-agent-0"]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "csvtodb_data_pvc" {
  metadata {
    name      = "csvtodb-data-pvc"
    namespace = var.env_name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    volume_name        = kubernetes_persistent_volume.csvtodb_data_pv.metadata.0.name
    storage_class_name = kubernetes_storage_class.main_storage_class.metadata.0.name
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "csvtodb_logs_pvc" {
  metadata {
    name      = "csvtodb-logs-pvc"
    namespace = var.env_name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    volume_name        = kubernetes_persistent_volume.csvtodb_logs_pv.metadata.0.name
    storage_class_name = kubernetes_storage_class.main_storage_class.metadata.0.name
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}
