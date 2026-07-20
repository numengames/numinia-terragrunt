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
  source = "${include.envcommon.locals.rds_module_source}?ref=v9.12.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# Override parameters for this environment
# -

dependency "vpc" {
  config_path = "../../vpc" 
}


inputs = {
  name                                = "prod-hyperfy"
  engine                              = "aurora-postgresql"
  engine_version                      = "16.11"
  instance_class                      = "db.t4g.medium"
  vpc_id                              = dependency.vpc.outputs.vpc_id
  availability_zones                  = dependency.vpc.outputs.azs
  master_username                     = "postgres"
  backup_retention_predis             = 7
  preferred_backup_window             = "03:00-06:00"
  preferred_maintenance_window        = "thu:01:59-thu:02:29"
  port                                = "5432"
  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "prod-hyperfy"
  subnets                             = dependency.vpc.outputs.database_subnets
  create_db_subnet_group              = true
  create_security_group               = true
  performance_insights_enabled        = true
  allow_major_version_upgrade         = true
  apply_immediately                   = true
  deletion_protection                 = false
  instances = {
    instance-1 = {
      instance_class = "db.t4g.medium"
    }
  }
  tags = {
    Terraform = "true"
    Environment = "production"

  }
}