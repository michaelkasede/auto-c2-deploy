Rule: Apply when editing `.yml` or `.yaml` under **`ansible/`** (including `ansible/site.yml`, `ansible/roles/**`, and `ansible/inventory/**`).

- Use fully qualified collection names (FQCN), e.g. `ansible.builtin.apt`, `ansible.builtin.copy`, `community.docker.docker_container`.
- Every task must have a descriptive `name:`.
- Prefer play-level `become: true` for roles that require root; use task-level `become: false` only when a task must run without privilege escalation.
- Assume the inventory is dynamic (e.g. Terraform-driven); do not hardcode host IPs in playbooks.
- Ensure playbooks are idempotent (a second run should report no unintended changes).
- Use dynamic inventories where possible.
