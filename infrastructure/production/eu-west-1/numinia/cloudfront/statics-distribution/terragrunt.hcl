include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include the envcommon configuration for the component.
include "envcommon" {
  path = find_in_parent_folders("env.hcl")
  expose = true
  merge_strategy = "no_merge"
}

# Define dependencies
dependency "acm" {
  config_path = "../../../../us-east-1/numinia/acm/statics-numinia-certificate"
  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:us-east-1:241533135482:certificate/a4d43bfa-fa15-427f-92c8-e6fa7d58b6f4"
  }
  # skip_outputs = true
}

# Dependency on the S3 bucket
dependency "s3_bucket" {
  config_path = "../../s3/statics-bucket"
  mock_outputs = {
    s3_bucket_id = include.envcommon.locals.statics_s3_bucket_name
    s3_bucket_bucket_regional_domain_name = "${include.envcommon.locals.statics_s3_bucket_name}.s3.eu-west-1.amazonaws.com"
    s3_bucket_arn = "arn:aws:s3:::${include.envcommon.locals.statics_s3_bucket_name}"
  }
}

# Set the terraform source to the CloudFront module
terraform {
  source = "${include.envcommon.locals.cloudfront_module_source}?ref=v3.2.1"
}

# Inputs for the module
inputs = {
  create_distribution = true
  
  # S3 bucket configuration - reference existing bucket
  create_origin_access_identity = false
  create_origin_access_control = true
  create_s3_bucket = false
  
  # Origin configuration (required)
  origin = {
    statics-s3-origin = {
      domain_name         = dependency.s3_bucket.outputs.s3_bucket_bucket_regional_domain_name
      origin_id           = "statics-s3-origin"
      origin_path         = ""
      connection_attempts = 3
      connection_timeout  = 10
      origin_access_control = include.envcommon.locals.cloudfront_oac_name
    }
  }
  
  # Default cache behavior (required)
  default_cache_behavior = {
    target_origin_id       = "statics-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = include.envcommon.locals.cache_policy_id
    origin_request_policy_id = include.envcommon.locals.origin_request_policy_id
    use_forwarded_values   = false
  }
  
  # Origin Access Control
  origin_access_control = {
    "${include.envcommon.locals.cloudfront_oac_name}" = {
      description      = "CloudFront OAC for ${include.envcommon.locals.statics_s3_bucket_name} S3 bucket"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }
  
  # Configure S3 bucket policy for CloudFront
  attach_policy = true
  s3_bucket_name = dependency.s3_bucket.outputs.s3_bucket_id
  s3_bucket_policy_statements = {
    cloudfront_oac = {
      sid = "AllowCloudFrontServicePrincipalReadOnly"
      effect = "Allow"
      actions = ["s3:GetObject"]
      resources = ["${dependency.s3_bucket.outputs.s3_bucket_arn}/*"]
      principals = [{
        type = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }]
      condition = {
        test = "StringEquals"
        variable = "AWS:SourceArn"
        values = [include.envcommon.locals.cloudfront_distribution_arn]
      }
    }
  }
  
  # CloudFront configuration
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Numinia Static Assets CDN"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  wait_for_deployment = true
  aliases             = [include.envcommon.locals.statics_s3_bucket_name]
  
  # SSL Certificate from ACM
  viewer_certificate = {
    acm_certificate_arn      = dependency.acm.outputs.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  # Custom error responses
  custom_error_response = [
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    },
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]
  
  # Geo restrictions
  geo_restriction = {
    restriction_type = "none"
  }
  
  # Tags
  tags = {
    Name        = "${include.envcommon.locals.statics_s3_bucket_name}-cdn"
    Environment = include.envcommon.locals.env
    Terraform   = "true"
  }
}
