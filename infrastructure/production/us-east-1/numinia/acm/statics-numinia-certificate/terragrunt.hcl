include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include the envcommon configuration for the component.
include "envcommon" {
  path = find_in_parent_folders("env.hcl")
  expose = true
  merge_strategy = "no_merge"
}

# Configure the module version to use
terraform {
  source = "${include.envcommon.locals.acm_module_source}?ref=v5.0.0"
}

# Override remote state to use eu-west-1 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "productionterragrunt-tf-state-production-eu-west-1"
    key            = "production/us-east-1/numinia/acm/statics-numinia-certificate/tf.tfstate"
    region         = "eu-west-1"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to create SSL certificate
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  domain_name = "statics.numinia.xyz"
  
  # Use the existing Route53 zone ID from environment variables
  zone_id     = include.envcommon.locals.route53_zone_id
  
  # Use DNS validation with Route53
  validation_method = "DNS"
  
  # Enable Route53 record creation for automatic validation
  create_route53_records = true
  
  # No need for subject alternative names since we're focusing on statics.numinia.xyz
  subject_alternative_names = []
  
  # Wait for validation to complete
  wait_for_validation = true
  
  tags = {
    Name        = "statics-numinia-xyz"
    Environment = "production"
    Terraform   = "true"
  }
} 