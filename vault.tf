locals {
  vault_projects_range =  fileset(path.module, "VAULT_PROJECTS/*.yaml")

  vault_projects_users = {
    for users, val in local.vault_projects_range:
      regex("^[^.]*", basename("${users}")) => yamldecode(file("${val}"))["users"] if yamldecode(file("${val}"))["users"] != null
  }

  vault_user_list = flatten([
    for project in keys(local.vault_projects_users) : [
      for user in local.vault_projects_users[project] : {
        project   = project
        user      = regex("^[^/.]*", user)
        policy    = regex("[^/]+$", user) != regex("^[^/.]*", user) ? regex("[^/]+$", user) : yamldecode(file("VAULT_PROJECTS/${project}.yaml"))["rw_policy"][0]
      }
    ]
  ])

  vault_projects_groups = {
    for groups, val in local.vault_projects_range:
      regex("^[^.]*", basename("${groups}")) => yamldecode(file("${val}"))["groups"] if yamldecode(file("${val}"))["groups"] != null
  }

  vault_group_list = flatten([
    for project in keys(local.vault_projects_groups) : [
      for group in local.vault_projects_groups[project] : {
        project   = project
        group     = regex("^[^/.]*", group)
        policy    = regex("[^/]+$", group) != regex("^[^/.]*", group) ? regex("[^/]+$", group) : yamldecode(file("VAULT_PROJECTS/${project}.yaml"))["rw_policy"][0]
      }
    ]
  ])

  vault_rw_policies = {
    for rw_policies, val in local.vault_projects_range:
      rw_policies => yamldecode(file("${val}"))["rw_policy"] if yamldecode(file("${val}"))["rw_policy"] != null
  }

  vault_rw_policies_list = flatten([
    for project in keys(local.vault_rw_policies) : [
      for policy in local.vault_rw_policies[project] : {
        project   = regex("^[^.]*", basename(project))
        policy    = policy
        secret_engine = yamldecode(file(project))["secrets_engine"]
      }
    ]
  ])

  vault_ro_policies = {
    for ro_policies, val in local.vault_projects_range:
      ro_policies => yamldecode(file("${val}"))["ro_policy"] if yamldecode(file("${val}"))["ro_policy"] != null
  }

  vault_ro_policies_list = flatten([
    for project in keys(local.vault_ro_policies) : [
      for policy in local.vault_ro_policies[project] : {
        project   = regex("^[^.]*", basename(project))
        policy    = policy
        secret_engine = yamldecode(file(project))["secrets_engine"]
      }
    ]
  ])

  vault_ro_policies_variables = flatten([
    for project in keys(local.vault_ro_policies) : {
      project   = regex("^[^.]*", basename(project))
      policy    = yamldecode(file(project))["ro_policy"][0]
    }
  ])
}

#создаем тестовый секрет. disable_read не отслеживает изменения секрета
resource "vault_generic_secret" "project_secrets" {
  for_each = {
    for engines in local.vault_projects_range:
      regex("^[^.]*", basename("${engines}")) => yamldecode(file("${engines}"))["secrets_engine"]
  }
  path = "${each.value}/${each.key}/test-secret"
  disable_read = "true"
  data_json = <<EOT
{
  "app":   "test"
}
EOT
}

#Создаем политики rw и ro 
resource "vault_policy" "vault_policy_rw" {
  for_each = {
    for policy in local.vault_rw_policies_list: "${policy.project}.${policy.policy}" => policy
  }
  name = join("-", [each.value.project, each.value.policy])
  policy = templatefile(join("", ["configs/vault-policy-templates/", "${each.value.policy}", ".tpl"]), {
    secret_engine = each.value.secret_engine
    vault_project = each.value.project
  })
}

resource "vault_policy" "vault_policy_ro" {
  for_each = {
    for policy in local.vault_ro_policies_list: "${policy.project}.${policy.policy}" => policy
  }
  name = join("-", [each.value.project, each.value.policy])
  policy = templatefile(join("", ["configs/vault-policy-templates/", "${each.value.policy}", ".tpl"]), {
    secret_engine = each.value.secret_engine
    vault_project = each.value.project
  })
}

#привязываем группу AD к политике rw
resource "vault_ldap_auth_backend_group" "vault_ldap_auth_group" {
  for_each = {
    for group in local.vault_group_list: "${group.project}.${group.group}" => group
  }
  groupname = each.value.group
  policies  = [join("-", [each.value.project, each.value.policy])]
  backend   = "ldap"
}

#привязываем пользователя AD к политике rw
resource "vault_ldap_auth_backend_user" "vault_ldap_auth_user" {
  depends_on = [vault_policy.vault_policy_rw]
  for_each = {
    for user in local.vault_user_list: "${user.project}.${user.user}" => user
  }
  username = each.value.user
  policies  = [join("-", [each.value.project, each.value.policy])]
  backend   = "ldap"
}

#создаем approle и привязываем к ней политику ro
resource "vault_approle_auth_backend_role" "vault_approle_auth" {
  depends_on = [vault_policy.vault_policy_ro]
  for_each = {
    for policy in local.vault_ro_policies_list: "${policy.project}.${policy.policy}" => policy
  }
  backend        = "approle"
  role_name      = join("-", [each.value.project, each.value.policy])
  token_policies = [join("-", [each.value.project, each.value.policy])]
  secret_id_num_uses = try(yamldecode(file("VAULT_PROJECTS/${each.value.project}.yaml"))["optional_configs"]["${each.value.policy}"]["token_num_uses"], "0")
  token_num_uses = try(yamldecode(file("VAULT_PROJECTS/${each.value.project}.yaml"))["optional_configs"]["${each.value.policy}"]["token_num_uses"], "100") 
  token_ttl = try(yamldecode(file("VAULT_PROJECTS/${each.value.project}.yaml"))["optional_configs"]["${each.value.policy}"]["token_ttl"], "60") 
  token_max_ttl = try(yamldecode(file("VAULT_PROJECTS/${each.value.project}.yaml"))["optional_configs"]["${each.value.policy}"]["token_max_ttl"], "120")
}

#создаем ресурс secret-id
resource "vault_approle_auth_backend_role_secret_id" "approle_secret_id" {
  depends_on = [vault_approle_auth_backend_role.vault_approle_auth]
  for_each = {
    for policy in local.vault_ro_policies_list: "${policy.project}.${policy.policy}" => policy
  }
  backend        = "approle"
  role_name = join("-", [each.value.project, each.value.policy])
}

#Выводим role_id и secret_id в лог пайплайна
resource "null_resource" "output_role_id_secret_id" {
  depends_on = [vault_approle_auth_backend_role_secret_id.approle_secret_id]
  for_each = {
    for policy in local.vault_ro_policies_list: "${policy.project}.${policy.policy}" => policy if yamldecode(file("VAULT_PROJECTS/${policy.project}.yaml"))["gitlab_url"] == null || "${policy.policy}" != yamldecode(file("VAULT_PROJECTS/${policy.project}.yaml"))["ro_policy"][0]
  }
  provisioner "local-exec" {
    command = <<EOT
echo "<=====================================>"
echo "role-id and secret-id of project ${each.value.project}, policy ${each.value.policy}"
echo "role-id: ${vault_approle_auth_backend_role.vault_approle_auth["${each.value.project}.${each.value.policy}"].role_id}"
echo "secret-id: ${nonsensitive(vault_approle_auth_backend_role_secret_id.approle_secret_id["${each.value.project}.${each.value.policy}"].secret_id)}"
echo "<=====================================>"
EOT
  }
}

#Добавляем переменные в Gitlab, только от первой аппроли в проекта, role_id и secret_id последующих выводятся в лог пайплайна
resource "gitlab_group_variable" "gitlab_vault_role_id" {
  depends_on = [vault_approle_auth_backend_role_secret_id.approle_secret_id]
  for_each = {
    for policy in local.vault_ro_policies_variables: "${policy.project}.${policy.policy}" => policy if yamldecode(file("VAULT_PROJECTS/${policy.project}.yaml"))["gitlab_url"] != null
  }
  group             = regex("(?:.*?\\/){3}([^*]*)", "${yamldecode(file("VAULT_PROJECTS/${each.value.project}.yaml"))["gitlab_url"]}")[0]
  key               = "VAULT_ROLE_ID"
  value             = vault_approle_auth_backend_role.vault_approle_auth["${each.value.project}.${each.value.policy}"].role_id
  protected         = false
  masked            = true
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}

resource "gitlab_group_variable" "gitlab_vault_secret_id" {
  depends_on = [vault_approle_auth_backend_role_secret_id.approle_secret_id]
  for_each = {
    for policy in local.vault_ro_policies_variables: "${policy.project}.${policy.policy}" => policy if yamldecode(file("VAULT_PROJECTS/${policy.project}.yaml"))["gitlab_url"] != null
  }
  group             = regex("(?:.*?\\/){3}([^*]*)", "${yamldecode(file("VAULT_PROJECTS/${each.value.project}.yaml"))["gitlab_url"]}")[0]
  key               = "VAULT_SECRET_ID"
  value             = nonsensitive(vault_approle_auth_backend_role_secret_id.approle_secret_id["${each.value.project}.${each.value.policy}"].secret_id)
  protected         = false
  masked            = true
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}