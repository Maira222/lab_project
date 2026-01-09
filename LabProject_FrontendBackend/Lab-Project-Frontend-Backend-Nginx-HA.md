🧪 Lab Project – Terraform + Ansible Roles: Nginx Frontend with 3 Backend HTTPD Servers (HA + Auto-Config)
Estimated Duration: 5–6 hours
Environment: GitHub Codespace (Linux) with Terraform, AWS CLI, Python, and Ansible available or installable.

Final repo name (on GitHub):
CC_<YourName>_<YourRollNumber>/LabProject_FrontendBackend

🎯 Learning Outcomes
By completing this lab project, you must demonstrate that you can:

Design a small multi-tier AWS architecture using Terraform.

Use Ansible roles to separate responsibilities for:

Frontend Nginx configuration.
Backend HTTPD configuration.
(Optional but recommended) Common base configuration.
Configure Nginx as a reverse proxy / load balancer with:

2 active backend HTTPD servers.
1 backup backend (used only on primary failure).
Integrate Terraform and Ansible so that running:

terraform apply -auto-approve
Creates all EC2 instances.
Automatically runs the relevant Ansible role-based playbooks to fully configure the system (no manual ansible-playbook after apply).
Document and structure your repo in a production-like way (modules, roles, templates).
