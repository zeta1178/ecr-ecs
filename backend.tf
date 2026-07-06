terraform {
  backend "s3" {
    bucket         = "cruz-sbx-tfstate"
    key            = "AMZ_USWEST2/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    # use_lockfile   = true
    assume_role = {
      role_arn = "arn:aws:iam::992690408789:role/TFAmzAutomationRole"
    }
  }
}