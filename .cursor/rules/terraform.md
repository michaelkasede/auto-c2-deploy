Rule: Apply when editing `.tf` or `.hcl` files.

- Always use `required_providers` blocks with specific version constraints.
- Prioritize data sources for AMIs and machine images over hardcoded IDs.
- Prefer a standard layout: **`variables.tf`**, **`main.tf`**, **`outputs.tf`**, and **`providers.tf`**.
- **Generated / checked-in configs** under `cloud-configs/<provider>/terraform/` may start as a single `main.tf`; when editing that tree, split new provider/output blocks into **`providers.tf`** / **`outputs.tf`** to converge on the standard layout.
- Ensure every resource has **tags** (AWS/Azure) or **labels** (GCP) for cost tracking where the provider supports it. (Example: `google_compute_firewall` in `hashicorp/google` ~> 4.x does not support `labels`; use naming + instance/network labels instead.)
- ALWAYS use specific versions for providers.
- Prefer `for_each` over `count` for resources when it improves stability of addresses and references.
- Never hardcode secrets; use `var.*`, Vault, or environment-based authentication.
- When creating VMs, always output public IPs (e.g. redirector) for Ansible inventory.
