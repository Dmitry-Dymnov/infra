terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    harbor = {
      source  = "BESTSELLER/harbor"
      version = "3.7.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "15.11.0"
    }
    vault = {
      source = "hashicorp/vault"
      version = "3.15.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
    external = {
      source = "hashicorp/external"
      version = "2.3.1"
    }
  }
  required_version = ">= 0.15"
}