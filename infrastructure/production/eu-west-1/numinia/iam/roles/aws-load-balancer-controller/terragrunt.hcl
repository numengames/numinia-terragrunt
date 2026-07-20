include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${include.envcommon.locals.iam_role_sa_module_source}?ref=v6.2.1"
}

# IRSA role for the AWS Load Balancer Controller (kube-system:aws-load-balancer-controller).
# Previously this role + its ServiceAccount were created by hand and were NOT in code; codified here so the
# Kourier LoadBalancer service provisions automatically on a rebuild. The module's built-in flag creates the
# AWSLoadBalancerControllerIAMPolicy, so nothing external is needed.
inputs = {
  name            = "numinia-production-eks-aws-load-balancer-controller"
  use_name_prefix = false

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    this = {
      provider_arn               = "arn:aws:iam::${include.envcommon.locals.aws_account_id}:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/${include.envcommon.locals.oidc_provider}"
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}
