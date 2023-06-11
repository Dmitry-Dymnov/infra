path "${secret_engine}/${vault_project}/test/*"
{
  capabilities = ["read", "list"]
}
path "${secret_engine}/${vault_project}/*"
{
  capabilities = ["list"]
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