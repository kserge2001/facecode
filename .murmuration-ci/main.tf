terraform {
 required_providers {
aws = {
source = "hashicorp/aws"
 version = "5.36.0"
 }
}
}

# ~~~~~~~~~~~~~~~~~~~~ Configure the AWS provider ~~~~~~~~~~~~~~~~~~~~

provider "aws" {
region = var.region
}

# ~~~~~~~~~~~~~~~~~~~~~~~~ Create the bucket ~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_s3_bucket" "bucket1" {

 bucket = var.bucket_name
 force_destroy = true
 
}

# ~~~~~~~~~~~ Configure public access parameters in the bucket ~~~~~~~~
resource "aws_s3_bucket_ownership_controls" "rule" {

 bucket = aws_s3_bucket.bucket1.id
 rule {
 object_ownership = "BucketOwnerPreferred"
 }

}
resource "aws_s3_bucket_public_access_block" "bucket_access_block" {
bucket = aws_s3_bucket.bucket1.id

 block_public_acls  = false
 block_public_policy  = false
 ignore_public_acls = false
 restrict_public_buckets = false
}
resource "aws_s3_bucket_acl" "bucket1-acl" {

 bucket = aws_s3_bucket.bucket1.id
 acl = "public-read"

 depends_on = [ aws_s3_bucket_ownership_controls.rule, aws_s3_bucket_public_access_block.bucket_access_block,aws_s3_bucket_acl.bucket1-acl]

}

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.bucket1.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
  depends_on = [ aws_s3_bucket_acl.bucket1-acl ]
}
data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.bucket1.arn,
      "${aws_s3_bucket.bucket1.arn}/*",
    ]
  }
}
resource "null_resource" "upload_files" {
  provisioner "local-exec"  {
      command = <<EOT
        cd .. 
        aws s3 sync ${var.cp-path} s3://${aws_s3_bucket.bucket1.bucket}/ 
      EOT
}
depends_on = [aws_s3_bucket.bucket1 , aws_s3_bucket_policy.allow_access]
}
resource "aws_s3_bucket_website_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket1.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key    = "error.html"
  }
  depends_on = [aws_s3_bucket.bucket1]
}

locals {
  s3_origin_id   = "${var.bucket_name}-origin"
  s3_domain_name = "${var.bucket_name}.s3-website.${var.region}.amazonaws.com"
}
resource "aws_cloudfront_distribution" "web-distribution" {
  
  enabled = true
  
  origin {
    origin_id                = local.s3_origin_id
    domain_name              = local.s3_domain_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }
  default_cache_behavior {
    
    target_origin_id = local.s3_origin_id
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  price_class = "PriceClass_200"
  depends_on = [ aws_s3_bucket.bucket1 , null_resource.upload_files, aws_s3_bucket_acl.bucket1-acl, aws_s3_bucket_policy.allow_access ]
  
}

resource "null_resource" "generate_test_website_script" {
  provisioner "local-exec" {
    command = templatefile("test-website.tpl", {
      parlai_website_endpoint = aws_cloudfront_distribution.web-distribution.domain_name
    })
    
  }
   provisioner "local-exec" {
    command = "chmod 777 test-website.sh"
  }
  depends_on = [ aws_cloudfront_distribution.web-distribution ]
}
output "INFO" {
  value = "AWS Resources  has been provisioned. Go to http://${aws_cloudfront_distribution.web-distribution.domain_name}"
}
