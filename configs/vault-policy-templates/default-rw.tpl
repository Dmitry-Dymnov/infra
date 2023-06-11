path "${secret_engine}/${vault_project}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/auth/*"
{
  capabilities = ["read"]
}
path "sys/mounts"
{
  capabilities = ["read"]
}
path "${secret_engine}/*"
{
  capabilities = ["list"]
}