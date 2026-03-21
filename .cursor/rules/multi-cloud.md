Rule: Apply globally.

- AWS: Use IMDSv2 and standard VPC subnets.
- GCP: Ensure google_compute_firewall rules are tagged correctly to instances.
- Azure: Always check for location consistency within Resource Groups.
- Never generate code containing access_key, secret_key, or service account JSON keys. Use - environment-based authentication.
