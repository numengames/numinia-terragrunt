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
  source = "${include.envcommon.locals.vpc_module_source}?ref=v5.19.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Override parameters for this environment
# ---------------------------------------------------------------------------------------------------------------------

# For production, we want to specify bigger instance classes and storage, so we specify override parameters here. These
# inputs get merged with the common inputs from the root and the envcommon terragrunt.hcl
inputs = {
  name = "numinia-vpc"
  cidr = include.envcommon.locals.vpc_cidr
  public_subnet_suffix = "public"
  private_subnet_suffix = "private"
  azs             = include.envcommon.locals.azs
  private_subnets = include.envcommon.locals.private_subnets
  public_subnets  = include.envcommon.locals.public_subnets
  # Do NOT remove — RDS depends on these; dropping the line destroys them on the next apply.
  database_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"  
    "kubernetes.io/cluster/production-numinia" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/production-numinia" = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}