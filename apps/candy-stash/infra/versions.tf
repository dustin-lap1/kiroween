terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }

  # Partial backend: scripts/Plan-App.ps1 writes backend.hcl (bucket, lock
  # table, profile) from the app's account record. Never hardcode it here.
  backend "s3" {}
}

provider "aws" {
  region  = "us-east-1" # The only region the Organization allows (SCP).
  profile = var.aws_profile

  # Safety check: Terraform refuses to run against any other account, so a
  # wrong AWS_PROFILE can never touch the wrong app.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}
