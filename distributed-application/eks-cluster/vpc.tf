## Set the target region according to whatever edge_city was chosen
provider "aws" {
  region = lookup(var.parent_region, var.edge_city)
}

## Opt-in to the relevant AWS Local Zone using its group name
resource "aws_ec2_availability_zone_group" "local_zone" {
  count         = lookup(var.true_local_zone, var.edge_city) ? 1 : 0
  group_name    = lookup(var.local_zone_group_name, var.edge_city)
  opt_in_status = "opted-in"
}


# ## Opt-in to the relevant AWS Wavelength Zone using its group name
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
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

## Create the first subnet in the parent region for EKS to use (AZ b)
resource "aws_subnet" "parent-region-subnet-a" {
  availability_zone                           = "${lookup(var.parent_region, var.edge_city)}a"
  cidr_block                                  = "10.0.1.0/24"
  vpc_id                                      = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "ip-name"
  tags = {
    Name                                        = "${var.cluster_name}-parent-region-subnet-a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

## Create the second subnet in the parent region for EKS to use (AZ a)
resource "aws_subnet" "parent-region-subnet-b" {
  availability_zone                           = "${lookup(var.parent_region, var.edge_city)}b"
  cidr_block                                  = "10.0.2.0/24"
  vpc_id                                      = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "ip-name"

  tags = {
    Name                                        = "${var.cluster_name}-parent-region-subnet-b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

## Create a subnet in the relevant AWS Local Zone
## Note: AZ c in the parent region is used if no Local Zone exists there

resource "aws_subnet" "true-local-zone-subnet" {
  count                                       = lookup(var.true_local_zone, var.edge_city) ? 1 : 0
  availability_zone_id                        = lookup(var.local_zone_id, var.edge_city)
  cidr_block                                  = "10.0.3.0/24"
  vpc_id                                      = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "ip-name"

  tags = {
    Name                                        = "${var.cluster_name}-local-zone-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

resource "aws_subnet" "false-local-zone-subnet" {
  count                                       = lookup(var.true_local_zone, var.edge_city) ? 0 : 1
  availability_zone_id                        = lookup(var.local_zone_id, var.edge_city)
  cidr_block                                  = "10.0.3.0/24"
  vpc_id                                      = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "ip-name"

  tags = {
    Name                                        = "${var.cluster_name}-local-zone-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

## Create a subnet in the relevant AWS Wavelength Zone
resource "aws_subnet" "wavelength-zone-subnet" {
  availability_zone_id                        = lookup(var.wavelength_zone_id, var.edge_city)
  cidr_block                                  = "10.0.4.0/24"
  vpc_id                                      = aws_vpc.k8s-distributed.id
  map_public_ip_on_launch                     = false
  enable_resource_name_dns_a_record_on_launch = true
  private_dns_hostname_type_on_launch         = "ip-name"

  tags = {
    Name                                        = "${var.cluster_name}-wavelength-zone-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

resource "aws_internet_gateway" "k8s-distributed-ig" {
  vpc_id = aws_vpc.k8s-distributed.id

  tags = {
    Name = "${var.cluster_name}-internet-gateway"
  }
}

resource "aws_ec2_carrier_gateway" "k8s-distributed-cg" {
  vpc_id = aws_vpc.k8s-distributed.id

  tags = {
    Name = "${var.cluster_name}-carrier-gateway"
  }
}

resource "aws_route_table" "k8s-distributed-region-rt" {
  vpc_id = aws_vpc.k8s-distributed.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s-distributed-ig.id
  }

  tags = {
    Name = "${var.cluster_name}-region-rt"
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

  tags = {
    Name = "${var.cluster_name}-wavelength-rt"
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

resource "aws_route_table_association" "k8s-distributed-region-rta-local-zone" {
  subnet_id      = lookup(var.true_local_zone, var.edge_city) == true ? aws_subnet.true-local-zone-subnet[0].id : aws_subnet.false-local-zone-subnet[0].id
  route_table_id = aws_route_table.k8s-distributed-region-rt.id
}


## Only the Wavelength Zone subnet gets associated to the special route table
resource "aws_route_table_association" "k8s-distributed-wavelength-rta" {
  subnet_id      = aws_subnet.wavelength-zone-subnet.id
  route_table_id = aws_route_table.k8s-distributed-wavelength-rt.id
}

## Create Private VPC endpoints in the parent region for EKS
## see: https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html
resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.ec2"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true
  tags = {
    Name = "${var.cluster_name}-ec2-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-ecr-dkr-endpoint"
  }

}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.k8s-distributed-region-rt.id,
    aws_route_table.k8s-distributed-wavelength-rt.id
  ]

  tags = {
    Name = "${var.cluster_name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "elb" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.elasticloadbalancing"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-elb-endpoint"
  }

}

resource "aws_vpc_endpoint" "xray" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.xray"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-xray-endpoint"
  }

}

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-logs-endpoint"
  }

}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.sts"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-sts-endpoint"
  }

}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.ssm"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-ssm-endpoint"
  }

}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.ssmmessages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-ssmmessages-endpoint"
  }

}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.k8s-distributed.id
  service_name      = "com.amazonaws.${lookup(var.parent_region, var.edge_city)}.ec2messages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.parent-region-subnet-a.id,
    aws_subnet.parent-region-subnet-b.id
  ]

  security_group_ids = [
    aws_security_group.endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-ec2messages-endpoint"
  }

}

## We need to manually create Security Groups because we're using self-managed
## node groups in EKS

## This SG is for the private endpoints. We're allowing all traffic from within
## the VPC to talk to these. 
resource "aws_security_group" "endpoint_sg" {
  name        = "endpoint-sg"
  description = "private endpoint traffic"
  vpc_id      = aws_vpc.k8s-distributed.id
  ingress {
    description = "Allow all from VPC and both SGs"
    self        = true
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
    security_groups = [
      aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id,
      aws_security_group.node_sg.id
    ]
  }

  egress {
    description = "All all to VPC"
    self        = true
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "${var.cluster_name}-private-endpoint-sg"
  }
}

## This SG is for the self-managed node groups. They need to be able to 
## talk to and from the EKS control plane elements, as well as allow app
## traffic in and out

resource "aws_security_group" "node_sg" {
  name        = "self-managed-node-sg"
  description = "wide open"
  vpc_id      = aws_vpc.k8s-distributed.id

  ingress {
    description     = "eks cluster to nodes"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
    cidr_blocks     = ["10.0.0.0/16"]
    security_groups = [aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description = "nodeport inbound"
    from_port   = 30000
    to_port     = 30002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP inbound"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-node-group-sg"
  }
}

## this is needed so members of the self managed node groups can talk to the private EKS API
resource "aws_security_group_rule" "allow_node_groups_to_eks_cluster" {
  type                     = "ingress"
  to_port                  = 0
  protocol                 = "-1"
  from_port                = 0
  security_group_id        = aws_eks_cluster.k8s-distributed.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.node_sg.id
}
