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
  source = "${include.envcommon.locals.efs_module_source}?ref=v1.6.5"
}

# ---------------------------------------------------------------------------------------------------------------------
# Override parameters for this environment
# ---------------------------------------------------------------------------------------------------------------------

dependency kms {
    config_path = "../../kms/numinia-efs-key"
}

dependency vpc {
    config_path = "../../vpc"
}

# For production, we want to specify bigger instance classes and storage, so we specify override parameters here. These
# inputs get merged with the common inputs from the root and the envcommon terragrunt.hcl
inputs = {

  # File system
  name           = "numinia-eks"
  encrypted      = true
  kms_key_arn    = dependency.kms.outputs.key_arn

  lifecycle_policy = {
    transition_to_ia = "AFTER_90_DAYS"
  }

  # Mount targets / security group
  mount_targets = {
    "eu-west-1a" = {
      subnet_id = dependency.vpc.outputs.private_subnets[0]
    }
    "eu-west-1b" = {
      subnet_id = dependency.vpc.outputs.private_subnets[1]
    }
    "eu-west-1c" = {
      subnet_id = dependency.vpc.outputs.private_subnets[2]
    }
  }
  security_group_description = "Example EFS security group"
  security_group_vpc_id      = dependency.vpc.outputs.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    }
  }

  # Backup policy
  enable_backup_policy = true

  tags = {
    Terraform   = "true"
    Environment = "production"
  }

}