terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.69"
    }
  }
}
