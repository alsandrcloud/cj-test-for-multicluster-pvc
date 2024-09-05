provider "aws" {
  region = "us-west-2"
}

# Get default VPC and it's subnets
data "aws_vpc" "selected" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

locals {
  subnet_ids = data.aws_subnets.default.ids
}

# Security group for EFS allowing NFS access
resource "aws_security_group" "efs_access" {
  name        = "efs-access-sg"
  description = "Allow NFS access for EFS"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EFS file system
resource "aws_efs_file_system" "efs" {
  creation_token = "cj-test-aws-efs"
}

# Create mount targets in each subnet
resource "aws_efs_mount_target" "efs_mount" {
  for_each        = toset(local.subnet_ids)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_access.id]
}

# Module for first EKS cluster
module "eks_one" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                       = "cj-test-one"
  cluster_version                    = "1.30"
  cluster_endpoint_public_access     = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                             = data.aws_vpc.selected.id
  subnet_ids                         = local.subnet_ids
  control_plane_subnet_ids           = local.subnet_ids

  eks_managed_node_group_defaults = {
    instance_types = [ "t2.large", "t2.medium", "t2.small"]
  }

  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2
    }
  }

  tags = {
    Environment = "dev"
    Cluster     = "cj-test-one"
  }
}

# Module for second EKS cluster
module "eks_two" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                       = "cj-test-two"
  cluster_version                    = "1.30"
  cluster_endpoint_public_access     = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                             = data.aws_vpc.selected.id
  subnet_ids                         = local.subnet_ids
  control_plane_subnet_ids           = local.subnet_ids

  eks_managed_node_group_defaults = {
    instance_types = [ "t2.large", "t2.medium", "t2.small" ]
  }

  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2
    }
  }

  tags = {
    Environment = "dev"
    Cluster     = "cj-test-two"
  }
}

# Output EFS File System ID for use in Persistent Volumes 
output "efs_file_system_id" {
  value = aws_efs_file_system.efs.id
}
