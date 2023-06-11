#Доки по настройке провайдера https://registry.terraform.io/providers/BESTSELLER/harbor/latest/docs
resource "harbor_config_auth" "ldap" {
  auth_mode            = "ldap_auth"
  ldap_url             = "openldap.default.svc.cluster.local:389"
  ldap_search_dn       = "cn=admin,dc=example,dc=org"
  ldap_search_password = "Not@SecurePassw0rd"
  ldap_base_dn         = "dc=example,dc=org"
  ldap_uid             = "email"
  ldap_verify_cert     = false
}

resource "harbor_garbage_collection" "main" {
  schedule         = "Daily"
  delete_untagged  = true
}

resource "harbor_registry" "main" {
  provider_name = "docker-hub"
  name          = "test_docker_harbor"
  endpoint_url  = "https://hub.docker.com"
}

resource "harbor_interrogation_services" "main" {
  vulnerability_scan_policy = "daily"
}