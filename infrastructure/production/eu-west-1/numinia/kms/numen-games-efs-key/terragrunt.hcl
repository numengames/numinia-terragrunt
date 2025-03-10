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
  source = "${include.envcommon.locals.kms_module_source}?ref=v3.1.1"
}

# ---------------------------------------------------------------------------------------------------------------------
# Override parameters for this environment
# ---------------------------------------------------------------------------------------------------------------------

inputs = { 
  description = "Numen Games EFS key usage"
  key_usage   = "ENCRYPT_DECRYPT"
  aliases     = ["numen-games-efs"]

  tags = {
    Terraform   = "true"
    Environment = "production"
    Purpose     = "numen-games-storage"
  }
} 