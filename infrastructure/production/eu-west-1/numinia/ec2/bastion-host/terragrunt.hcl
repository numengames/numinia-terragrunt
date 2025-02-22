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
  source = "${include.envcommon.locals.ec2_module_source}?ref=v5.7.1"
}

dependency "vpc" {
  config_path = "../../vpc" 
}


# For production, we want to specify bigger instance classes and storage, so we specify override parameters here. These
# inputs get merged with the common inputs from the root and the envcommon terragrunt.hcl
inputs = {
  name = "numinia-bastion-host"
  instance_type          = "t3.micro"
  key_name               = "numinia-prod-pem"
  vpc_security_group_ids = [include.envcommon.locals.bastion_host_sg_id]
  subnet_id              = dependency.vpc.outputs.public_subnets[0]
  associate_public_ip_address = true
  iam_role_name = include.envcommon.locals.bastion_host_ec2_role_name
  tags = {
    Terraform   = "true"
    Environment = "production"
  }

}