resource "aws_iam_role" "k8s-distributed-cluster" {
  name = var.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "k8s-distributed-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.k8s-distributed-cluster.name
}

resource "aws_iam_role_policy_attachment" "k8s-distributed-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.k8s-distributed-cluster.name
}

resource "aws_iam_role_policy_attachment" "k8s-distributed-AmazonSSMManagedInstanceCore-parent" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = module.self_managed_node_group_parent_region.iam_role_name
}

resource "aws_iam_role_policy_attachment" "k8s-distributed-AmazonSSMManagedInstanceCore-localzone" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = module.self_managed_node_group_local_zone.iam_role_name
}

resource "aws_iam_role_policy_attachment" "k8s-distributed-AmazonSSMManagedInstanceCore-wavelength" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = module.self_managed_node_group_wavelength.iam_role_name
}
