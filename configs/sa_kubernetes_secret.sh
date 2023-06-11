#!/bin/bash
service_account_path="SERVICE_ACCOUNTS"
for file in $service_account_path/*.yaml; do
project_name="$(basename "$file" | sed 's/\(.*\)\..*/\1/' | grep "[a-z0-9-]")"
if [ -n "$(echo $project_name)" ]; then
k8s_clusters=$(cat $service_account_path/$(basename "$file") | yq .k8s_clusters.[])
for cluster in $k8s_clusters; do
cat <<- xx
data "kubernetes_secret" "$project_name-$cluster" {
  metadata {
    name = join("-", ["$project_name", "token"])
    namespace = "projects-accounts"
  }
  provider = kubernetes.$cluster
}

resource "gitlab_group_variable" "$project_name-$cluster-token" {
  group             = "$(cat $service_account_path/$(basename "$file") | grep "^[^#;]" | grep gitlab_url | awk '{print $2;}' | sed -r 's:(.*)(/)$:\1:' | sed 's:^\([^/]*/\)\{3\}::')"
  key               = replace(join("-", ["TOKEN", upper("$cluster")]), "-", "_")
  value             = nonsensitive(lookup(data.kubernetes_secret.$project_name-$cluster.data, "token"))
  protected         = false
  masked            = true
  environment_scope = "*"
  lifecycle { 
   ignore_changes = all 
}
}
xx
done
fi
done