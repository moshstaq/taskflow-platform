# Bindings has no outputs consumed by other Terraform modules.
# It is the terminal tier in the dependency chain.
#
# Values needed by Helm charts (managed identity client IDs, Key Vault URI)
# are read directly from foundation outputs in the service pipeline,
# or set as static values in charts/*/values.yaml after first apply.
