## Set the target region according to whatever edge_city was chosen
provider "aws" {
  region = lookup(var.parent_region, var.edge_city)
}

## Opt-in to the relevant AWS Local Zone using its group name
resource "aws_ec2_availability_zone_group" "local_zone" {
  group_name    = lookup(var.local_zone_group_name, var.edge_city)
  opt_in_status = "opted-in"
}

## Opt-in to the relevant AWS Wavelength Zone using its group name
resource "aws_ec2_availability_zone_group" "wavelength_zone" {
  group_name    = lookup(var.wavelength_group_name, var.edge_city)
  opt_in_status = "opted-in"
}

## Create VPC in the parent region
resource "aws_vpc" "k8s-distributed" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name"                                      = "terraform-eks-k8s-distributed-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

## Create the first subnet in the parent region for EKS to use (AZ b)
resource "aws_subnet" "parent-region-subnet-a" {
  availability_zone       = "${lookup(var.parent_region, var.edge_city)}a"
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "terraform-eks-k8s-distributed-node-parent-region"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

## Create the second subnet in the parent region for EKS to use (AZ a)
resource "aws_subnet" "parent-region-subnet-b" {
  availability_zone       = "${lookup(var.parent_region, var.edge_city)}b"
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "terraform-eks-k8s-distributed-node-parent-region"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

## Create a subnet in the relevant AWS Local Zone
## Note: AZ c in the parent region is used if no Local Zone exists there
resource "aws_subnet" "local-zone-subnet" {
  availability_zone_id    = lookup(var.local_zone, var.edge_city)
  cidr_block              = "10.0.3.0/24"
  vpc_id                  = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "terraform-eks-k8s-distributed-node-local-zone"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

## Create a subnet in the relevant AWS Wavelength Zone
resource "aws_subnet" "wavelength-zone-subnet" {
  availability_zone_id = lookup(var.wavelength_zone, var.edge_city)
  cidr_block           = "10.0.4.0/24"
  vpc_id               = aws_vpc.k8s-distributed.id

  tags = {
    "Name"                                      = "terraform-eks-k8s-distributed-node-wavelength-zone"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

resource "aws_internet_gateway" "k8s-distributed-ig" {
  vpc_id = aws_vpc.k8s-distributed.id

  tags = {
    Name = "terraform-eks-k8s-distributed-ig"
  }
}

resource "aws_ec2_carrier_gateway" "k8s-distributed-cg" {
  vpc_id = aws_vpc.k8s-distributed.id

  tags = {
    Name = "terraform-eks-k8s-distributed-cg"
  }
}

resource "aws_route_table" "k8s-distributed-region-rt" {
  vpc_id = aws_vpc.k8s-distributed.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s-distributed-ig.id
  }
}

## The subnet in the AWS Wavelength Zone needs a special route table
## so it knows to go out the Carrier Gateway for 0.0.0.0/0
resource "aws_route_table" "k8s-distributed-wavelength-rt" {
  vpc_id = aws_vpc.k8s-distributed.id

  route {
    cidr_block         = "0.0.0.0/0"
    carrier_gateway_id = aws_ec2_carrier_gateway.k8s-distributed-cg.id
  }
}

## Parent Region and Local Zone subnets all use the Internet Gateway
## so they get associated to the primary route table
resource "aws_route_table_association" "k8s-distributed-region-rta-a" {
  subnet_id      = aws_subnet.parent-region-subnet-a.id
  route_table_id = aws_route_table.k8s-distributed-region-rt.id
}

resource "aws_route_table_association" "k8s-distributed-region-rta-b" {
  subnet_id      = aws_subnet.parent-region-subnet-b.id
  route_table_id = aws_route_table.k8s-distributed-region-rt.id
}

resource "aws_route_table_association" "k8s-distributed-region-rta-c" {
  subnet_id      = aws_subnet.local-zone-subnet.id
  route_table_id = aws_route_table.k8s-distributed-region-rt.id
}

## Only the Wavelength Zone subnet gets associated to the special route table
resource "aws_route_table_association" "k8s-distributed-wavelength-rta" {
  subnet_id      = aws_subnet.wavelength-zone-subnet.id
  route_table_id = aws_route_table.k8s-distributed-wavelength-rt.id
}

## We need to manually create Security Groups because we're using self-managed
## node groups in EKS

resource "aws_security_group" "node_sg" {
  name        = "self-managed-node-sg"
  description = "allow traffic needed by EKS"
  vpc_id      = aws_vpc.k8s-distributed.id

  ingress {
    description     = "TLS from VPC"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Cluster API to node kubelets"
    protocol        = "tcp"
    from_port       = 10250
    to_port         = 10250
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Node to node CoreDNS"
    protocol        = "tcp"
    from_port       = 53
    to_port         = 53
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Node to node CoreDNS UDP"
    protocol        = "udp"
    from_port       = 53
    to_port         = 53
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Node to node ingress on ephemeral ports"
    protocol        = "tcp"
    from_port       = 1025
    to_port         = 65535
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Cluster API to node 4443/tcp webhook"
    protocol        = "tcp"
    from_port       = 4443
    to_port         = 4443
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Cluster API to node 6443/tcp webhook"
    protocol        = "tcp"
    from_port       = 6443
    to_port         = 6443
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Cluster API to node 8443/tcp webhook"
    protocol        = "tcp"
    from_port       = 8443
    to_port         = 8443
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Cluster API to node 9443/tcp webhook"
    protocol        = "tcp"
    from_port       = 9443
    to_port         = 9443
    self            = true
    cidr_blocks     = [aws_vpc.k8s-distributed.cidr_block]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
