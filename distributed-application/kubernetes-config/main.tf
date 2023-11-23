## Set the target region according to whatever edge_city was chosen
provider "aws" {
  region = lookup(var.parent_region, var.edge_city)
}

data "aws_eks_cluster" "default" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "default" {
  name = var.cluster_name
}

data "kubernetes_nodes" "localzone" {
  metadata {
    labels = {
      "topology.kubernetes.io/zone" = lookup(var.local_zone, var.edge_city)
    }
  }
}

# data "kubernetes_nodes" "wavelength" {
#   metadata {
#     labels = {
#       "topology.kubernetes.io/zone" = lookup(var.wavelength_zone, var.edge_city)
#     }
#   }
# }

data "kubernetes_nodes" "region" {
  metadata {
    labels = {
      "topology.kubernetes.io/region" = lookup(var.parent_region, var.edge_city)
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.default.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.default.token
  }
}

resource "local_sensitive_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name = var.cluster_name,
    clusterca    = data.aws_eks_cluster.default.certificate_authority[0].data,
    endpoint     = data.aws_eks_cluster.default.endpoint,
  })
  filename = "./kubeconfig-${var.cluster_name}"
}

# resource "kubernetes_namespace" "app-wavelength" {
#   metadata {
#     name = "app-wavelength"

#     labels = {
#       apps.kubernetes.io/app = "app-wavelength"
#     }
#   }
# }

resource "kubernetes_namespace" "app-localzone" {
  metadata {
    name = "app-localzone"

    labels = {
      "apps.kubernetes.io/app" = "app-localzone"
    }
  }
}

resource "kubernetes_namespace" "app-region" {
  metadata {
    name = "app-region"

    labels = {
      "apps.kubernetes.io/app" = "app-region"
    }
  }

}

resource "kubernetes_node_taint" "localzone" {
  count = length(data.kubernetes_nodes.localzone.nodes)
  metadata {
    name = data.kubernetes_nodes.localzone.nodes[count.index].metadata.0.name
  }
  taint {
    key    = "app"
    value  = "app-localzone"
    effect = "NoSchedule"
  }
}

resource "kubernetes_node_taint" "region" {
  count = length(data.kubernetes_nodes.region.nodes)
  metadata {
    name = data.kubernetes_nodes.region.nodes[count.index].metadata.0.name
  }
  taint {
    key    = "app"
    value  = "app-region"
    effect = "NoSchedule"
  }
}

resource "kubernetes_deployment" "app-localzone-deployment" {
  metadata {
    name      = "localzone-deployment"
    namespace = "distributed-app-localzone"
    labels = {
      app = "app-localzone"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app-localzone"
      }
    }
    template {
      metadata {
        labels = {
          app = "app-localzone"
        }
      }

      spec {
        toleration {
          key   = "app"
          value = "app-localzone"

        }
        container {
          name  = "nginx"
          image = "public.ecr.aws/nginx/nginx:1.23"
          port {
            name           = "http"
            container_port = 80
          }
          image_pull_policy = "IfNotPresent"
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
  depends_on = [
    kubernetes_node_taint.region,
    kubernetes_node_taint.localzone
  ]
}
