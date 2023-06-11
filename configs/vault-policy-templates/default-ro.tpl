path "${secret_engine}/${vault_project}/*"
{
  capabilities = ["read", "list"]
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