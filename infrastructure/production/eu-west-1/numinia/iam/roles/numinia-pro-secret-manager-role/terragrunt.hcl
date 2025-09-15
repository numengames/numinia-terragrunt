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
  source = "${include.envcommon.locals.iam_role_sa_module_source}?ref=v6.2.1"
}



# For production, we want to specify bigger instance classes and storage, so we specify override parameters here. These
# inputs get merged with the common inputs from the root and the envcommon terragrunt.hcl
inputs = { 
    name = "numinia-pro-secret-manager-role"
    use_name_prefix = false
    oidc_providers = {
        this = {
        provider_arn               = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/${include.envcommon.locals.oidc_provider}"
        namespace_service_accounts = ["numinia:numinia"]
        }
    }

    policies = {
        numinia-pro-secret-manager-policy = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:policy/numinia-pro-secret-manager-policy"
        numinia-statics-bucket                  = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:policy/numinia-statics-bucket"
    }
  

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}

# data "aws_iam_policy" "active_inference_pre_policy" {
#   arn = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:policy/active-inference-pre-secret-manager-policy"
# }

# data "aws_iam_policy" "active_inference_pro_policy" {
#   arn = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:policy/active-inference-pro-secret-manager-policy"
# }

# data "aws_iam_policy" "numinia_statics_bucket_policy" {
#   arn = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:policy/numinia-statics-bucket"
# }