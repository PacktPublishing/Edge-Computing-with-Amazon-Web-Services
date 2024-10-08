
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_eks_cluster_auth" "default" {
  name = var.cluster_name
}
provider "kubernetes" {
  host                   = aws_eks_cluster.k8s-distributed.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.k8s-distributed.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

## this creates the EKS cluster itself
resource "aws_eks_cluster" "k8s-distributed" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.k8s-distributed-cluster.arn

  vpc_config {
    subnet_ids              = [aws_subnet.parent-region-subnet-a.id, aws_subnet.parent-region-subnet-b.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }
  
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.k8s-distributed-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.k8s-distributed-AmazonEKSVPCResourceController,
  ]
}



## this uses a module to deploy a self-managed node group to the Parent Region
module "self_managed_node_group_parent_region" {
  source = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"

  name                = "parent-region"
  cluster_name        = var.cluster_name
  cluster_version     = var.kubernetes_version
  cluster_endpoint    = aws_eks_cluster.k8s-distributed.endpoint
  cluster_auth_base64 = aws_eks_cluster.k8s-distributed.certificate_authority[0].data
  cluster_service_cidr = "172.20.0.0/16"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id
  ]

  vpc_security_group_ids = [
    aws_security_group.node_sg.id
  ]

  min_size     = 1
  max_size     = 2
  desired_size = 1

  launch_template_name = "parent-region-self-mng"
  instance_type        = "t3.medium"

  tags = {
    Environment = "region"
    Terraform   = "true"
  }

  depends_on = [
    aws_eks_cluster.k8s-distributed,
    aws_security_group_rule.allow_private_subnet_to_eks_cluster
  ]

}

## this uses a module to deploy a self-managed node group to the AWS Wavelength Zone
module "self_managed_node_group_wavelength" {
  source = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"

  name                = "wavelength"
  cluster_name        = var.cluster_name
  cluster_version     = var.kubernetes_version
  cluster_endpoint    = aws_eks_cluster.k8s-distributed.endpoint
  cluster_auth_base64 = aws_eks_cluster.k8s-distributed.certificate_authority[0].data
  cluster_service_cidr = "172.20.0.0/16"

  subnet_ids = [aws_subnet.wavelength-zone-subnet.id]

  vpc_security_group_ids = [
    aws_security_group.node_sg.id
  ]

  min_size     = 1
  max_size     = 2
  desired_size = 1

  launch_template_name = "wavelength-self-mng"
  instance_type        = "t3.medium"

  tags = {
    Environment = "wavelength"
    Terraform   = "true"
  }

  depends_on = [
    aws_eks_cluster.k8s-distributed,
    aws_security_group_rule.allow_private_subnet_to_eks_cluster
  ]

}

## this uses a module to deploy a self-managed node group to the AWS Local Zone
module "self_managed_node_group_local_zone" {
  source = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"

  name                = "local-zone"
  cluster_name        = var.cluster_name
  cluster_version     = var.kubernetes_version
  cluster_endpoint    = aws_eks_cluster.k8s-distributed.endpoint
  cluster_auth_base64 = aws_eks_cluster.k8s-distributed.certificate_authority[0].data
  cluster_service_cidr = "172.20.0.0/16"

  subnet_ids = lookup(var.true_local_zone, var.edge_city) == true ? [aws_subnet.true-local-zone-subnet[0].id] : [aws_subnet.false-local-zone-subnet[0].id]

  vpc_security_group_ids = [
    aws_security_group.node_sg.id
  ]

  min_size     = 1
  max_size     = 2
  desired_size = 1

  launch_template_name = "localzone-self-mng"
  instance_type        = "t3.medium"

  tags = {
    Environment = "local_zone"
    Terraform   = "true"
  }

  depends_on = [
    aws_eks_cluster.k8s-distributed,
    aws_security_group_rule.allow_private_subnet_to_eks_cluster
  ]

}


## This is how the k8s configmaps are created. These translate internal k8s RBAC
## to AWS IAM users/roles. We're allowing admin rights to whatever user deployed
## this in Terraform, and allowing the rights needed for self-managed nodes to
## join the cluster
locals {
  user_map_obj = [
    {
      userarn  = data.aws_iam_session_context.current.arn
      username = "admin"
      groups   = ["system:masters"]
    }
  ]

  role_map_obj = [
    {
      rolearn  = module.self_managed_node_group_wavelength.iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
    {
      rolearn  = module.self_managed_node_group_parent_region.iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
    {
      rolearn  = module.self_managed_node_group_local_zone.iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }

  ]

  aws_auth_configmap_data = {
    mapRoles = yamlencode(local.role_map_obj)
    mapUsers = yamlencode(local.user_map_obj)
  }
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data
  lifecycle {
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  depends_on = [
    kubernetes_config_map.aws_auth,
  ]
}

## This section creates a pull through cache for public.ecr.aws
resource "aws_ecr_pull_through_cache_rule" "ecr_public" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}

resource "aws_ecr_registry_policy" "allow_node_groups_to_ecr" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowECRPullThroughCache",
        Effect = "Allow",
        Principal = {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        },
        Action = [
          "ecr:CreateRepository",
          "ecr:BatchImportUpstreamImage"
        ],
        Resource = "arn:aws:ecr:${lookup(var.parent_region, var.edge_city)}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}
output "cluster_url" {
  value = aws_eks_cluster.k8s-distributed.endpoint
}

output "cluster_ca" {
  value = aws_eks_cluster.k8s-distributed.certificate_authority[0].data
}
