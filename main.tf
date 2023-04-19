###################################################################################################
# EKS seleted version
#################################################################################################

terraform {
  required_providers {
    aws = {
      version = ">= 0.13"
      source  = "hashicorp/aws"
    }
  }
}

#####################################################################################################
# IAM Role
#####################################################################################################
module "allow_eks_access_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.3.1"

  name          = "allow-eks-access"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


#######################################################################################
# IAM role attched
#######################################################################################
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-iam-role.name
}
####################################################################################################
# vpc
####################################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.3"

  name = "main"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.0.0.0/19", "10.0.32.0/19"]
  public_subnets  = ["10.0.64.0/19", "10.0.96.0/19"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "staging"
  }
}

#######################################################################################
# node group
######################################################################################

resource "aws_eks_node_group" "workernodes" {
  cluster_name    = aws_eks_cluster.devopsthehardway-eks.name
  node_group_name = "devopsthehardway-workernodes"
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = [var.subnet_id_1, var.subnet_id_2]
  instance_types  = ["t3.large"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEKS_CNI_Policy,
    /*#aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,*/
  ]
}

#######################################################################################
# EKS cluster
#######################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.29.0"

  cluster_name    = "my-eks"
  cluster_version = "1.23"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
    disk_size = 50
  }

  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 2
      max_size     = 3

      labels = {
        role = "general"
      }

      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
    }

    spot = {
      desired_size = 1
      min_size     = 2
      max_size     = 3

      labels = {
        role = "spot"
      }

      taints = [{
        key    = "yar"
        value  = "spot"
        effect = "NO_SCHEDULE"
      }]

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Environment = "staging"
  }
}
