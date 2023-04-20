/*
 * © Copyright 2023 HP Development Company, L.P.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "random_id" "bucket-name" {
  byte_length = 3
}

locals {
  bucket_name = "${var.prefix}pcoip-scripts-${random_id.bucket-name.hex}"
}

resource "aws_s3_bucket" "scripts" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "scripts-lifecycle" {
  bucket = aws_s3_bucket.scripts.bucket
  # AWS Foundational Security Best Practices v1.0.0
  # Severity Low	S3.13	S3 buckets should have lifecycle policies configured
  # This rule aims to satisfy the security requirement: A transition lifecycle rule action is set 
  # to automatically move Amazon S3 objects from the default S3 standard tier to Intelligent-Tiering 
  # 30 days after they were created in order to reduce S3 storage costs. 
  # No expiration lifecycle rule action specified.
  rule {
    id = "config"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  # AWS Foundational Security Best Practices v1.0.0
  # Severity Medium S3.1	S3 Block Public Access setting should be enabled
  bucket = aws_s3_bucket.scripts.id
  # These rules block the public access to the bucket as it contains scripts for VM.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "scripts" {
  # AWS Foundational Security Best Practices v1.0.0
  # Severity Medium S3.5	S3 buckets should require requests to use Secure Socket Layer.
  # This policy explicitly denies all actions on the bucket and objects when the request 
  # meets the condition "aws:SecureTransport": "false".
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.scripts.arn,
      "${aws_s3_bucket.scripts.arn}/*",
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  policy = data.aws_iam_policy_document.scripts.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  # AWS Foundational Security Best Practices v1.0.0
  # Severity Medium	S3.4	S3 buckets should have server-side encryption enabled
  bucket = aws_s3_bucket.scripts.bucket
  # The server-side encryption algorithm can be choose between AES256 and KMS
  # Choose KMS here to provide added protection against unauthorized access of 
  # the objects in Amazon S3 and centrally manage keys.
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_logging" "scripts" {
  # AWS Foundational Security Best Practices v1.0.0
  # Severity Medium	S3.9	S3 bucket server access logging should be enabled
  bucket = aws_s3_bucket.scripts.id

  target_bucket = aws_s3_bucket.scripts.id
  target_prefix = "access_log/"
}


resource "aws_sns_topic" "scripts-sns" {
  # AWS Foundational Security Best Practices v1.0.0
  # Severity Medium S3.11	S3 buckets should have event notifications enabled
  name = local.bucket_name
  # Added policy so that Amazon SNS topic is the event destination where S3 can send notification messages
  policy = <<POLICY
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:${local.bucket_name}",
        "Condition":{
            "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.scripts.arn}"}
        }
    }]
}
POLICY
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.scripts.id
  # Specify SNS topic to enable notifications when an object is created using any API operation
  topic {
    topic_arn = aws_sns_topic.scripts-sns.arn
    events = ["s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
      "s3:ObjectTagging:*",
    "s3:LifecycleExpiration:*"]
    filter_suffix = ".log"
  }
}

# resolve error "AccessControlListNotSupported: The bucket does not allow ACLs"
# resource "aws_s3_bucket_acl" "scripts" {
#   bucket = aws_s3_bucket.scripts.id
#   acl    = "private"
# }
