include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include the envcommon configuration for the component.
include "envcommon" {
  path = find_in_parent_folders("env.hcl")
  expose = true
  merge_strategy = "no_merge"
}

# Define dependencies on CloudFront
dependency "cloudfront" {
  config_path = "../../cloudfront/statics-distribution"
  mock_outputs = {
    cloudfront_distribution_domain_name = "d2n62b0vfhcai2.cloudfront.net"
    cloudfront_distribution_hosted_zone_id = include.envcommon.locals.cloudfront_hosted_zone_id
  }
}

# Set the terraform source
terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-route53.git//modules/records?ref=v2.10.2"
}

# Inputs for the Route53 record module
inputs = {
  zone_id = include.envcommon.locals.route53_zone_id
  
  records = [
    {
      name    = split(".", include.envcommon.locals.statics_s3_bucket_name)[0]
      type    = "A"
      alias   = {
        name    = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
        zone_id = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        evaluate_target_health = false
      }
    }
  ]
} 