locals {
  harbor_projects_range =  fileset(path.module, "HARBOR_PROJECTS/*.yaml")
  harbor_projects_names = {
    for basename, val in local.harbor_projects_range:
      regex("^[^.]*", basename(basename)) => basename
  }
  harbor_projects_users = {
    for users, val in local.harbor_projects_range:
      regex("^[^.]*", basename("${users}")) => yamldecode(file("${val}"))["users"] if yamldecode(file("${val}"))["users"] != null
  }
  harbor_user_list = flatten([
    for project in keys(local.harbor_projects_users) : [
      for user in local.harbor_projects_users[project] : {
        project   = project
        user      = regex("^[^/.]*", user)
        role      = regex("[^/]+$", user)
      }
    ]
  ])
  harbor_projects_groups = {
    for groups, val in local.harbor_projects_range:
      regex("^[^.]*", basename("${groups}")) => yamldecode(file("${val}"))["groups"] if yamldecode(file("${val}"))["groups"] != null
  }
  harbor_group_list = flatten([
    for project in keys(local.harbor_projects_groups) : [
      for group in local.harbor_projects_groups[project] : {
        project   = project
        group     = regex("^[^/.]*", group)
        role      = regex("[^/]+$", group)
      }
    ]
  ])
  gitlab_harbor_projects_urls = {
    for url, val in local.harbor_projects_range:
      regex("^[^.]*", basename("${url}")) => regex("(?:.*?\\/){3}([^*]*)", "${yamldecode(file("${val}"))["gitlab_url"]}") if yamldecode(file("${val}"))["gitlab_url"] != null
  }
}

#Создаем проект
resource "harbor_project" "harbor_projects" {
  for_each = local.harbor_projects_names
  name                   = each.key
  public                 = coalesce(yamldecode(file("${each.value}"))["public"], "false")
  vulnerability_scanning = coalesce(yamldecode(file("${each.value}"))["vulnerability_scanning"], "false")
  storage_quota          = coalesce(yamldecode(file("${each.value}"))["storage_quota"], "3")
}

#Добавляем в созданный проект технического пользователя
resource "harbor_project_member_user" "harbor-api-user" {
  for_each = local.harbor_projects_names
  project_id    = harbor_project.harbor_projects["${each.key}"].id
  user_name     = "harbor-api"
  role          = "developer"
}

#Добавляем в созданный проект пользователей 
resource "harbor_project_member_user" "harbor-user" {
  for_each = {
    for user in local.harbor_user_list: "${user.project}.${user.user}" => user
  }
  project_id    = harbor_project.harbor_projects["${each.value.project}"].id
  user_name     = each.value.user
  role          = each.value.role
}

#Добавляем в созданный проект группы пользователей 
data "external" "ldap" {
  for_each = {
    for group in local.harbor_group_list: "${group.project}.${group.group}" => group
  }
  program= ["bash", "${path.module}/configs/ldapsearch_harbor.sh"]
  query = {
    harbor_group_name = each.value.group
  }
}

resource "harbor_project_member_group" "harbor-group" {
  for_each = {
    for group in local.harbor_group_list: "${group.project}.${group.group}" => group
  }
  project_id    = harbor_project.harbor_projects["${each.value.project}"].id
  group_name    = each.value.group
  role          = each.value.role
  type          = "ldap"
  ldap_group_dn = data.external["${each.value.project}.${each.value.group}"].result
}

#Добавляем переменные в GitLab
resource "gitlab_group_variable" "gitlab-harbor-user" {
  for_each = local.gitlab_harbor_projects_urls
  group             = each.value[0]
  key               = "CI_REGISTRY_USER"
  value             = "add_the_service_account_name"
  protected         = false
  masked            = false
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}

resource "gitlab_group_variable" "gitlab-harbor-password" {
  for_each = local.gitlab_harbor_projects_urls
  group             = each.value[0]
  key               = "CI_REGISTRY_PASSWORD"
  value             = "add_the_service_account_password"
  protected         = false
  masked            = true
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}

resource "gitlab_group_variable" "harbor_url" {
  for_each = local.gitlab_harbor_projects_urls
  group             = each.value[0]
  key               = "CI_REGISTRY"
  value             = var.CI_HARBOR_URL
  protected         = false
  masked            = false
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}