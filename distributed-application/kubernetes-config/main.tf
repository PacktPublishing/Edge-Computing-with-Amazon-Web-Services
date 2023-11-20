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

################################################################################
# aws-auth configmap
################################################################################

# locals {
#   node_iam_role_arns_non_windows = distinct(
#     compact(
#       concat(
#         [for group in module.eks_managed_node_group : group.iam_role_arn if group.platform != "windows"],
#         [for group in module.self_managed_node_group : group.iam_role_arn if group.platform != "windows"],
#         var.aws_auth_node_iam_role_arns_non_windows,
#       )
#     )
#   )

#   node_iam_role_arns_windows = distinct(
#     compact(
#       concat(
#         [for group in module.eks_managed_node_group : group.iam_role_arn if group.platform == "windows"],
#         [for group in module.self_managed_node_group : group.iam_role_arn if group.platform == "windows"],
#         var.aws_auth_node_iam_role_arns_windows,
#       )
#     )
#   )

#   fargate_profile_pod_execution_role_arns = distinct(
#     compact(
#       concat(
#         [for group in module.fargate_profile : group.fargate_profile_pod_execution_role_arn],
#         var.aws_auth_fargate_profile_pod_execution_role_arns,
#       )
#     )
#   )

#   aws_auth_configmap_data = {
#     mapRoles = yamlencode(concat(
#       [for role_arn in local.node_iam_role_arns_non_windows : {
#         rolearn  = role_arn
#         username = "system:node:{{EC2PrivateDNSName}}"
#         groups = [
#           "system:bootstrappers",
#           "system:nodes",
#         ]
#         }
#       ],
#       [for role_arn in local.node_iam_role_arns_windows : {
#         rolearn  = role_arn
#         username = "system:node:{{EC2PrivateDNSName}}"
#         groups = [
#           "eks:kube-proxy-windows",
#           "system:bootstrappers",
#           "system:nodes",
#         ]
#         }
#       ],
#       # Fargate profile
#       [for role_arn in local.fargate_profile_pod_execution_role_arns : {
#         rolearn  = role_arn
#         username = "system:node:{{SessionName}}"
#         groups = [
#           "system:bootstrappers",
#           "system:nodes",
#           "system:node-proxier",
#         ]
#         }
#       ],
#       var.aws_auth_roles
#     ))
#     mapUsers    = yamlencode(var.aws_auth_users)
#     mapAccounts = yamlencode(var.aws_auth_accounts)
#   }
# }

# resource "kubernetes_config_map" "aws_auth" {
#   count = var.create && var.create_aws_auth_configmap ? 1 : 0

#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = local.aws_auth_configmap_data

#   lifecycle {
#     # We are ignoring the data here since we will manage it with the resource below
#     # This is only intended to be used in scenarios where the configmap does not exist
#     ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
#   }
# }

# resource "kubernetes_config_map_v1_data" "aws_auth" {
#   count = var.create && var.manage_aws_auth_configmap ? 1 : 0

#   force = true

#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = local.aws_auth_configmap_data

#   depends_on = [
#     # Required for instances where the configmap does not exist yet to avoid race condition
#     kubernetes_config_map.aws_auth,
#   ]
# }
