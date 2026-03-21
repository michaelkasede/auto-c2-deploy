Rule: Apply when editing .tf or .hcl files.

- Always use required_providers blocks with specific version constraints.
- Prioritize data sources for AMIs and Machine Images over hardcoded IDs.
- Maintain a standard layout: variables.tf, main.tf, outputs.tf, and providers.tf.
- Ensure every resource has a tags or labels block for cost tracking.
- ALWAYS use specific versions for providers.
- Prefer `for_each` over `count` for resources.
- Never hardcode secrets; assume use of `var.secrets` or Vault.
- When creating VMs, always output their public IPs for Ansible inventory.
