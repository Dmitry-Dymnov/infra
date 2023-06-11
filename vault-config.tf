#Доки по настройке https://registry.terraform.io/providers/hashicorp/vault/latest/docs
resource "vault_mount" "gitlab-ci-kv1" {
  path        = "gitlab-ci-kv1"
  type        = "kv"
  options     = {
    "version" = "1" 
    }
  description = "KV Version 1 secret engine mount"
}

resource "vault_mount" "gitlab-ci-kv2" {
  path        = "gitlab-ci-kv2"
  type        = "kv"
  options     = {
    "version" = "2" 
    }
  description = "KV Version 2 secret engine mount"
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}

#создаем политику admin
resource "vault_policy" "admin" {
  name = "admin"
  policy = <<EOT
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/auth/*" {
  capabilities = ["create", "update", "delete", "sudo"]
}
path "sys/auth" {
  capabilities = ["read"]
}
path "sys/policy" {
  capabilities = ["read"]
}
path "sys/policy/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "gitlab-ci-kv1/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "gitlab-ci-kv2/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/mounts" {
  capabilities = ["read", "list"]
}
path "sys/health" {
  capabilities = ["read", "sudo"]
}
path "sys/capabilities" {
  capabilities = ["create", "update"]
}
path "sys/capabilities-self" {
  capabilities = ["create", "update"]
}
path "sys/audit/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

#Cоздаем approle и привязываем к ней политику admin
#token_num_uses должно быть равно 0, так при значении отличном от нуля, 
#полученный токен будет считаться ограниченым и не сможет создавать дочерние токены, которые создает провайдер terraform-a
#максимальное время жизни токена 20 минут
resource "vault_approle_auth_backend_role" "admin" {
  backend        = "approle"
  role_name      = "admin"
  token_policies = ["admin"]
  secret_id_num_uses = "0"
  token_num_uses = "0"
  token_ttl = "600" 
  token_max_ttl = "1200"
}
  
##создаем ресурс secret-id
resource "vault_approle_auth_backend_role_secret_id" "admin" {
  backend        = "approle"
  role_name = vault_approle_auth_backend_role.admin.role_name
}

#разово вывести role_id и secret_id
resource "null_resource" "admin" {
  provisioner "local-exec" {
    command = <<EOT
echo "role-id of admin: ${vault_approle_auth_backend_role.admin.role_id}"
echo "secret-id of admin: ${nonsensitive(vault_approle_auth_backend_role_secret_id.admin.secret_id)}"
EOT
  }
}

/*
resource "vault_ldap_auth_backend" "ldap" {
    path        = "ldap"
    url         = "ldaps://dc01.company.com:636"
    userdn      = "OU=FOO,DC=company,DC=com"
    binddn      = "CN=vault-service-account,OU=main,OU=FOO,DC=company,DC=com"
    bindpass    = var.LDAP_BIND_PASS
    userattr    = "samaccountname"
    groupdn     = "OU=FOO,DC=company,DC=com"
    certificate = <<EOT
-----BEGIN CERTIFICATE-----

*****Domain Certificate*****

-----END CERTIFICATE-----
EOT
    tls_max_version="tls13"
    insecure_tls = "false"
    starttls="true"
}
*/