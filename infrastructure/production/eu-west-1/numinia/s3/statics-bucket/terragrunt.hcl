include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include the envcommon configuration for the component.
include "envcommon" {
  path = find_in_parent_folders("env.hcl")
  expose = true
  merge_strategy = "no_merge"
}

# Set the terraform source to the S3 module
terraform {
  source = "${include.envcommon.locals.s3_module_source}?ref=v3.15.1"
}

# Inputs for the S3 bucket module
inputs = {
  bucket = include.envcommon.locals.statics_s3_bucket_name
  force_destroy = false
  
  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  # Encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  
  # Versioning
  versioning = {
    enabled = true
  }

  # Lifecycle — only the world-backup zips under `backups/` expire. The
  # prebuilt engine image lives under `backup-engine/` and is intentionally
  # NOT matched here, so it persists. World assets under `hyperfy-spaces/`
  # are untouched (no rule matches them).
  lifecycle_rule = [
    {
      id      = "expire-world-backups"
      enabled = true
      filter = {
        prefix = "backups/"
      }
      # Khepri-Forge streams each backup as a multipart upload; abort orphans
      # left by a failed job.
      abort_incomplete_multipart_upload_days = 7
      expiration = {
        days = 7
      }
      noncurrent_version_expiration = {
        days = 1
      }
    },
    # Expire noncurrent versions bucket-wide (the bucket once hoarded ~600 GB of stale versions).
    {
      id      = "expire-noncurrent-versions-global"
      enabled = true
      filter = {
        prefix = ""
      }
      abort_incomplete_multipart_upload_days = 7
      noncurrent_version_expiration = {
        days = 7
      }
    },
    {
      id      = "cleanup-expired-delete-markers"
      enabled = true
      filter = {
        prefix = ""
      }
      expiration = {
        expired_object_delete_marker = true
      }
    }
  ]

  # CORS configuration
  cors_rule = [
    {
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["*"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
  
  # Bucket policy para permitir acceso desde CloudFront
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowCloudFrontServicePrincipalReadOnly",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = "s3:GetObject",
        Resource = "arn:aws:s3:::${include.envcommon.locals.statics_s3_bucket_name}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = include.envcommon.locals.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
  
  # Tags
  tags = {
    Name        = include.envcommon.locals.statics_s3_bucket_name
    Environment = include.envcommon.locals.env
    Terraform   = "true"
  }
}