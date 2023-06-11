variable "CI_HARBOR_USER" {
    type        = string
    description = "Harbor admin user"
}

variable "CI_HARBOR_PASSWORD" {
    type        = string
    description = "Harbor admin password"
}

variable "CI_HARBOR_URL" {
    type        = string
    description = "Harbor url"
}

provider "harbor" {
  url = var.CI_HARBOR_URL
  username = var.CI_HARBOR_USER
  password = var.CI_HARBOR_PASSWORD
}

variable "CI_GITLAB_ADMIN_TOKEN" {
    type        = string
    description = "Gitlab admin token"
}

variable "CI_API_V4_URL" {
    type        = string
    description = "Gitlab api url"
}

provider "gitlab" {
  token = var.CI_GITLAB_ADMIN_TOKEN
  base_url = var.CI_API_V4_URL
}

variable "VAULT_URL" {
    type        = string
    description = "Vault url"
}

variable "VAULT_TOKEN" {
    type        = string
    description = "Vault admin token"
}

variable "LDAP_BIND_PASS" {
    type        = string
    description = "Service account password"
    sensitive = false
}

provider "vault" {
  address = var.VAULT_URL
  token = var.VAULT_TOKEN
}