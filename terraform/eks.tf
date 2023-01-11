module "eks" {
  source  = "terraform-aws-modules/eks/aws"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  eks_managed_node_group_defaults = {
    disk_size      = 8
    instance_types = ["t2.small"]
  }

  eks_managed_node_groups = {
    worker-group-1 = {
      min_size     = 0
      max_size     = 1
      desired_size = 0

      instance_types                = ["t2.small"]
      capacity_type                 = "ON_DEMAND"
      additional_security_group_ids = [aws_security_group.worker_group_sg_1.id]
    }

    worker-group-2 = {
      min_size     = 0
      max_size     = 1
      desired_size = 0

      instance_types                = ["t2.medium"]
      capacity_type                 = "ON_DEMAND"
      additional_security_group_ids = [aws_security_group.worker_group_sg_2.id]
    }
  }
}