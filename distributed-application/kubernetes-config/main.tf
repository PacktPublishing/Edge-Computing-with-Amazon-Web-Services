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

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "helm_release" "nginx_ingress" {
  namespace = kubernetes_namespace.test.metadata.0.name
  wait      = true
  timeout   = 600

  name = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "v4.8.3"
}
