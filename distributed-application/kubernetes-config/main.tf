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

## this section creates a list of k8s nodes (ec2 instances) in the localzone
## we need this later to apply k8s taints
data "kubernetes_nodes" "localzone" {
  metadata {
    labels = {
      "topology.kubernetes.io/zone" = lookup(var.local_zone, var.edge_city)
    }
  }
}
## this section creates a list of k8s nodes (ec2 instances) in wavelength
## we need this later to apply k8s taints
data "kubernetes_nodes" "wavelength" {
  metadata {
    labels = {
      "topology.kubernetes.io/zone" = lookup(var.wavelength_zone, var.edge_city)
    }
  }
}
## this section creates a list of k8s nodes (ec2 instances) in the region
## we need this later to apply k8s taints
data "kubernetes_nodes" "region" {
  metadata {
    labels = {
      "topology.kubernetes.io/zone" = "${lookup(var.parent_region, var.edge_city)}a",
      "topology.kubernetes.io/zone" = "${lookup(var.parent_region, var.edge_city)}b"
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

## create the namespaces, one for each location type
resource "kubernetes_namespace" "app-wavelength" {
  metadata {
    name = "app-wavelength"

    labels = {
      "apps.kubernetes.io/app" = "app-wavelength"
    }
  }
}

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

##these k8s taints prevent ANY pod from being scheduled - unless the pod/deployment
##specifically has a toleration set. this is how we're controlling where pods go
resource "kubernetes_node_taint" "localzone" {
  count = length(data.kubernetes_nodes.localzone.nodes)
  metadata {
    name = data.kubernetes_nodes.localzone.nodes[count.index].metadata.0.name
  }
  taint {
    key    = "apps.kubernetes.io/app"
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
    key    = "apps.kubernetes.io/app"
    value  = "app-region"
    effect = "NoSchedule"
  }
}

## this section kicks off our deployments into each location
resource "kubernetes_deployment" "app-localzone-deployment" {
  metadata {
    name      = "localzone-deployment"
    namespace = "distributed-app-localzone"
    labels = {
      "apps.kubernetes.io/app" = "app-localzone"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "apps.kubernetes.io/app" = "app-localzone"
      }
    }
    template {
      metadata {
        labels = {
          "apps.kubernetes.io/app" = "app-localzone"
        }
      }

      spec {
        toleration {
          key      = "apps.kubernetes.io/app"
          value    = "app-localzone"
          operator = "Equal"
          effect   = "NoSchedule"
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

resource "kubernetes_deployment" "app-region-deployment" {
  metadata {
    name      = "region-deployment"
    namespace = "distributed-app-region"
    labels = {
      "apps.kubernetes.io/app" = "app-region"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "apps.kubernetes.io/app" = "app-region"
      }
    }
    template {
      metadata {
        labels = {
          "apps.kubernetes.io/app" = "app-region"
        }
      }

      spec {
        toleration {
          key      = "apps.kubernetes.io/app"
          value    = "app-region"
          operator = "Equal"
          effect   = "NoSchedule"
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

output "region_nodes" {
  value = [for node in data.kubernetes_nodes.region.nodes : node.spec.0.provider_id]
}

output "localzone_nodes" {
  value = [for node in data.kubernetes_nodes.localzone.nodes : node.spec.0.provider_id]
}

output "wavelength_nodes" {
  value = [for node in data.kubernetes_nodes.wavelength.nodes : node.spec.0.provider_id]
}
