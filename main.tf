provider "aws" {
  region = var.region
}

# to be able to access account details
# aws_caller_identity : whos calling this account
data "aws_caller_identity" "my_account" {}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-s3-bucket-${data.aws_caller_identity.my_account.account_id}"
#  region = var.region

#  lifecycle_rule {
#    enabled = true
#    prefix = "files/"
#
#    # transition from standard to standardIA after 30days
#    noncurrent_version_transition {
#      days = 30
#      storage_class = "STANDARD_IA"
#    }
#
#    # transition from standardIA to glacier after 60days
#    noncurrent_version_transition {
#      days = 60
#      storage_class = "GLACIER"
#    }
#
#    # expire after 90days
#    noncurrent_version_expiration {
#      days = 90
#    }
#
#  }

  tags = {
    Type = "LOG"
    Tier = "STANDARD"
  }
}

# bucket access control list
resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.my_bucket.id
#  owner_id = data.aws_caller_identity.my_account.account_id
  acl = "public-read"

}

# bucket policy
resource "aws_s3_bucket_policy" "my-bucket-policy" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MyBucketPolicy",
  "Statement": [
    {
      "Sid": "IPAllow",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.my_bucket.bucket}/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "4.4.4.4/32"
        }
      }
    }
  ]
}
POLICY
}

#implement/enable versioning to keep track of changes to files
# and also access different versions of the files
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.my_bucket.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

# s3 bucket lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "versioning-bucket-config" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.bucket_versioning]

  bucket = aws_s3_bucket.my_bucket.bucket

  rule {
    id = "config"

    filter {
      prefix = "files/"
    }

    # expire after 90days
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # transition from standard to standardIA after 30days
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    # transition from standardIA to glacier after 60days
    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    status = "Enabled"
  }
}

# uploading a file to s3
resource "aws_s3_bucket_object" "readme_file" {

  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "files/readme.txt"

  source = "readme.txt"

  # etag to let terraform know the file has been changed
  # hash will be calculated everytime we make a change to the file
  etag = filemd5("readme.txt")
}
