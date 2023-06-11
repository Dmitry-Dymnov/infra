locals {
  sa_projects_range =  fileset(path.module, "SERVICE_ACCOUNTS/*.yaml")
  k8s_clusters = {
    for cluster, val in local.sa_projects_range:
      regex("^[^.]*", basename("${cluster}")) => yamldecode(file("${val}"))["k8s_clusters"] if yamldecode(file("${val}"))["k8s_clusters"] != null
  }
  k8s_clusters_list = flatten([
    for project in keys(local.k8s_clusters) : [
      for cluster in local.k8s_clusters[project] : {
        project      = project
        cluster      = cluster
        gitlab_grp   = regex("(?:.*?\\/){3}([^*]*)", "${yamldecode(file("SERVICE_ACCOUNTS/${project}.yaml"))["gitlab_url"]}")[0]
      }
    ]
  ])
}

resource "gitlab_group_variable" "kubernetes_clusters_urls" {
  for_each = {
    for cluster in local.k8s_clusters_list: "${cluster.project}.${cluster.cluster}" => cluster
  }
  group             = each.value.gitlab_grp
  key               = replace(join("-", ["URL", upper("${each.value.cluster}")]), "-", "_")
  value             = "${lookup(var.k8s_clusters["${each.value.cluster}"],"url")}"
  protected         = false
  masked            = false
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}

resource "gitlab_group_variable" "kubernetes_clusters_names" {
  for_each = {
    for cluster in local.k8s_clusters_list: "${cluster.project}.${cluster.cluster}" => cluster
  }
  group             = each.value.gitlab_grp
  key               = replace(join("-", ["CLUSTER", upper("${each.value.cluster}")]), "-", "_")
  value             = each.value.cluster
  protected         = false
  masked            = false
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}

resource "gitlab_group_variable" "bases_namespaces" {
  for_each = {
    for cluster in local.sa_projects_range: regex("^[^.]*", basename("${cluster}")) => cluster
  }
  group             = regex("(?:.*?\\/){3}([^*]*)", "${yamldecode(file("${each.value}"))["gitlab_url"]}")[0]
  key               = "K8S_NAMESPACE_BASE"
  value             = regex("^[^.]*", basename("${each.value}"))
  protected         = false
  masked            = false
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}
