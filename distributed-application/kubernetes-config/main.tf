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

locals {
  instance_id_list = split("/", data.kubernetes_nodes.wavelength.nodes[0].spec[0].provider_id)
}

## Terraform doesn't really understand wavelength, so lets manually create an EIP on the CGW 
## and attach it to our node. Note this is a good example of when you need to know the network
## border group id
resource "aws_eip" "wavelength_eip" {
  domain                    = "vpc"
  instance                  = element(local.instance_id_list, length(local.instance_id_list) - 1)
  associate_with_private_ip = data.kubernetes_nodes.wavelength.nodes[0].status[0].addresses[0].address
  network_border_group      = lookup(var.wavelength_zone, var.edge_city)
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
resource "kubernetes_namespace" "distributed-app-wavelength" {
  metadata {
    name = "distributed-app-wavelength"

    labels = {
      app = "app-wavelength"
    }
  }
}

resource "kubernetes_namespace" "distributed-app-localzone" {
  metadata {
    name = "distributed-app-localzone"

    labels = {
      app = "app-localzone"
    }
  }
}

resource "kubernetes_namespace" "distributed-app-region" {
  metadata {
    name = "distributed-app-region"

    labels = {
      app = "app-region"
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
    key    = "app"
    value  = "app-localzone"
    effect = "NoSchedule"
  }
}

resource "kubernetes_node_taint" "wavelength" {
  count = length(data.kubernetes_nodes.wavelength.nodes)
  metadata {
    name = data.kubernetes_nodes.wavelength.nodes[count.index].metadata.0.name
  }
  taint {
    key    = "app"
    value  = "app-wavelength"
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

## this section kicks off our deployments into each location
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
          key      = "app"
          value    = "app-localzone"
          operator = "Equal"
          effect   = "NoSchedule"
        }
        host_network = true
        container {
          name  = "nginx"
          image = "public.ecr.aws/e2t7i0t3/sample-edge-app:4"
          port {
            name           = "http"
            container_port = 80
          }
          image_pull_policy = "IfNotPresent"
          env {
            name  = "AWS_ZONE"
            value = lookup(var.local_zone, var.edge_city)
          }
          env {
            name  = "EDGE_CITY"
            value = var.edge_city
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
  depends_on = [
    kubernetes_node_taint.region,
    kubernetes_node_taint.localzone,
    kubernetes_node_taint.wavelength
  ]
}

resource "kubernetes_service" "app-localzone-service" {
  metadata {
    name      = "localzone-service"
    namespace = "distributed-app-localzone"
  }
  spec {
    selector = {
      app = "app-localzone"
    }
    external_traffic_policy = "Local"
    port {
      port        = 80
      target_port = 80
      node_port   = 30001
      name        = "localzone-port"
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}
resource "kubernetes_deployment" "app-region-deployment" {
  metadata {
    name      = "region-deployment"
    namespace = "distributed-app-region"
    labels = {
      app = "app-region"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app-region"
      }
    }
    template {
      metadata {
        labels = {
          app = "app-region"
        }
      }

      spec {
        toleration {
          key      = "app"
          value    = "app-region"
          operator = "Equal"
          effect   = "NoSchedule"
        }
        host_network = true
        container {
          name  = "nginx"
          image = "public.ecr.aws/e2t7i0t3/sample-edge-app:4"
          port {
            name           = "http"
            container_port = 80
          }
          image_pull_policy = "IfNotPresent"
          env {
            name  = "AWS_ZONE"
            value = lookup(var.parent_region, var.edge_city)
          }
          env {
            name  = "EDGE_CITY"
            value = var.edge_city
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
  depends_on = [
    kubernetes_node_taint.region,
    kubernetes_node_taint.localzone,
    kubernetes_node_taint.wavelength
  ]
}

resource "kubernetes_service" "app-region-service" {
  metadata {
    name      = "region-service"
    namespace = "distributed-app-region"
  }
  spec {
    selector = {
      "app" = "app-region"
    }
    external_traffic_policy = "Local"
    port {
      port        = 80
      target_port = 80
      node_port   = 30000
      name        = "region-port"
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

resource "kubernetes_deployment" "app-wavelength-deployment" {
  metadata {
    name      = "wavelength-deployment"
    namespace = "distributed-app-wavelength"
    labels = {
      app = "app-wavelength"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "app-wavelength"
      }
    }
    template {
      metadata {
        labels = {
          app = "app-wavelength"
        }
      }

      spec {
        toleration {
          key      = "app"
          value    = "app-wavelength"
          operator = "Equal"
          effect   = "NoSchedule"
        }
        host_network = true
        container {
          name  = "nginx"
          image = "public.ecr.aws/e2t7i0t3/sample-edge-app:4"
          port {
            name           = "http"
            container_port = 80
          }
          image_pull_policy = "IfNotPresent"
          env {
            name  = "AWS_ZONE"
            value = lookup(var.wavelength_zone, var.edge_city)
          }
          env {
            name  = "EDGE_CITY"
            value = var.edge_city
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
  depends_on = [
    kubernetes_node_taint.wavelength,
    kubernetes_node_taint.localzone,
    kubernetes_node_taint.region,
    aws_eip.wavelength_eip
  ]
}

resource "kubernetes_service" "app-wavelength-service" {
  metadata {
    name      = "wavelength-service"
    namespace = "distributed-app-wavelength"
  }
  spec {
    selector = {
      "app" = "app-wavelength"
    }
    external_traffic_policy = "Local"
    port {
      port        = 80
      target_port = 80
      node_port   = 30002
      name        = "wavelength-port"
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

output "region_address" {
  value = "http://${data.kubernetes_nodes.region.nodes[0].status[0].addresses[1].address}:30000"
}

output "localzone_address" {
  value = "http://${data.kubernetes_nodes.localzone.nodes[0].status[0].addresses[1].address}:30001"
}

output "wavelength_address" {
  value = "http://${aws_eip.wavelength_eip.carrier_ip}:30002"
}
