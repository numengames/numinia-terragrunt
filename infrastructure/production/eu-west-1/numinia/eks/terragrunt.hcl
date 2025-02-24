include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include the envcommon configuration for the component. The envcommon configuration contains settings that are common
# for the component across all environments.
include "envcommon" {
  path = find_in_parent_folders("env.hcl")
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
  merge_strategy = "no_merge"
}

# Configure the version of the module to use in this environment. This allows you to promote new versions one
# environment at a time (e.g., qa -> stage -> prod).
terraform {
  source = "${include.envcommon.locals.eks_module_source}?ref=v20.33.1"
}

dependency "vpc" {
  config_path = "../vpc" 
}


# For production, we want to specify bigger instance classes and storage, so we specify override parameters here. These
# inputs get merged with the common inputs from the root and the envcommon terragrunt.hcl
inputs = {
  cluster_name    = "production-numinia"
  cluster_version = "1.32"

  cluster_endpoint_public_access = false

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    aws-efs-csi-driver = {
      most_recent = true
      service_account_role_arn = include.envcommon.locals.efs_csi_role_arn
    }
  }

  vpc_id                                = dependency.vpc.outputs.vpc_id
  subnet_ids                            = dependency.vpc.outputs.private_subnets
  node_security_group_tags = {}

  eks_managed_node_groups = {
    numinia-node-group = {
      name           = "production-numinia-ng"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 3
      max_size     = 10
      desired_size = 3
      tags = {
        "name" : "production-numinia-cluster"
      }
    }

  }
  enable_cluster_creator_admin_permissions = true
  access_entries = {
    bastion-host-access = {
        kubernetes_groups = ["masters"]
        principal_arn = include.envcommon.locals.bastion_host_ec2_role_arn
        policy_associations = {
            permissions = {
                policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
                access_scope = {
                    type = "cluster"
                }
            }
        }
    },
    jesus-access = {
        kubernetes_groups = ["masters"]
        principal_arn = include.envcommon.locals.jesus_user_arn
        policy_associations = {
            permissions = {
                policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
                access_scope = {
                    type = "cluster"
                }
            }
        }
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "production"
  }
}
