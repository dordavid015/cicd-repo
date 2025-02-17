terraform {
  backend "s3" {
    bucket         = "dordavid-cicd-gh"
    key            = "terraform/state/app.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-1"
}

