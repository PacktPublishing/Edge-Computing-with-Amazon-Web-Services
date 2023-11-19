
data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

resource "aws_eks_cluster" "k8s-distributed" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.k8s-distributed-cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.parent-region-subnet-a.id, aws_subnet.parent-region-subnet-b.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.k8s-distributed-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.k8s-distributed-AmazonEKSVPCResourceController,
  ]
}

module "self_managed_node_group_wavelength" {
  source = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"

  name                = "wavelength-node-group"
  cluster_name        = var.cluster_name
  cluster_version     = var.kubernetes_version
  cluster_endpoint    = aws_eks_cluster.k8s-distributed.endpoint
  cluster_auth_base64 = base64encode(aws_eks_cluster.k8s-distributed.certificate_authority[0].data)

  subnet_ids = [aws_subnet.wavelength-zone-subnet.id]

  vpc_security_group_ids = [
    aws_security_group.node_sg.id
  ]

  min_size     = 1
  max_size     = 10
  desired_size = 1

  launch_template_name = "wavelength-self-mng"
  instance_type        = "t3.medium"

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

output "cluster_url" {
  value = aws_eks_cluster.k8s-distributed.endpoint
}

output "cluster_ca" {
  value = aws_eks_cluster.k8s-distributed.certificate_authority[0].data
}
