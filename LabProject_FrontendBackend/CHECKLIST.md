# 📋 Submission Checklist & Grading Reference

## Pre-Submission Checklist

### ✅ Required Files

- [ ] `main.tf` - Main Terraform configuration
- [ ] `variables.tf` - Variable definitions
- [ ] `outputs.tf` - Output definitions
- [ ] `locals.tf` - Local variables
- [ ] `templates/hosts.tpl` - Ansible inventory template
- [ ] `templates/extra_vars.tpl` - Extra variables template
- [ ] `ansible/ansible.cfg` - Ansible configuration
- [ ] `ansible/playbooks/site.yaml` - Main playbook
- [ ] `ansible/roles/backend/` - Backend role (complete)
- [ ] `ansible/roles/frontend/` - Frontend role (complete)
- [ ] `.gitignore` - Proper exclusions
- [ ] `README.md` - Comprehensive documentation
- [ ] `Lab-Project-Frontend-Backend-Nginx-HA.md` - Original lab document

### ✅ Role Structure Verification

Backend Role (`ansible/roles/backend/`):
- [ ] `tasks/main.yml` exists
- [ ] `handlers/main.yml` exists
- [ ] `templates/backend_index.html.j2` exists
- [ ] Installs httpd
- [ ] Starts and enables httpd
- [ ] Deploys unique index page per backend

Frontend Role (`ansible/roles/frontend/`):
- [ ] `tasks/main.yml` exists
- [ ] `handlers/main.yml` exists
- [ ] `templates/nginx_frontend.conf.j2` exists
- [ ] Installs nginx
- [ ] Starts and enables nginx
- [ ] Configures upstream with 2 primary + 1 backup

### ✅ Infrastructure Verification

- [ ] VPC created with correct CIDR
- [ ] Internet Gateway attached
- [ ] Public subnet created
- [ ] Route table with default route
- [ ] Security group allows SSH from your IP only
- [ ] Security group allows HTTP from anywhere
- [ ] 1 frontend EC2 instance created
- [ ] 3 backend EC2 instances created
- [ ] All instances have meaningful tags
- [ ] SSH key pair configured

### ✅ Automation Verification

- [ ] `null_resource` triggers Ansible automatically
- [ ] `terraform apply -auto-approve` completes without manual intervention
- [ ] Ansible inventory generated dynamically
- [ ] Extra vars file created with backend IPs
- [ ] No manual `ansible-playbook` command needed

### ✅ Functionality Verification

- [ ] All 3 backends serve distinct content
- [ ] Frontend accessible via HTTP
- [ ] Load balancing works (alternates between 2 primaries)
- [ ] Backup backend only used when primaries fail
- [ ] Each backend page shows correct hostname/IP
- [ ] Nginx logs show backend distribution

### ✅ Code Quality

- [ ] No hardcoded IPs (uses variables/outputs)
- [ ] Meaningful variable names
- [ ] Comments where needed
- [ ] Proper indentation and formatting
- [ ] No unnecessary code duplication

### ✅ Git Repository

- [ ] No `.tfstate` files committed
- [ ] No `.terraform/` directory committed
- [ ] No private SSH keys committed
- [ ] No AWS credentials committed
- [ ] No `terraform.tfvars` with sensitive data
- [ ] Clean commit history
- [ ] Descriptive commit messages

### ✅ Documentation

- [ ] README explains how to use the project
- [ ] Assumptions documented
- [ ] Prerequisites listed
- [ ] Testing instructions included
- [ ] Troubleshooting section provided

---

## 📊 Grading Rubric Reference

### A. Terraform Infrastructure Design (25 Marks)

| Criteria | Points | Verification |
|----------|--------|--------------|
| VPC, Subnet, IGW, Route Table correct | 8 | Check AWS Console or `terraform state list` |
| Security Groups properly scoped | 7 | Verify SSH limited to your IP, HTTP from 0.0.0.0/0 |
| 1 frontend + 3 backend instances with tags | 10 | Check instance tags and naming |

**Self-Check:**
```bash
# List all resources
terraform state list | grep -E '(vpc|subnet|gateway|route|security|instance)'

# Check instance tags
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value]'
```

### B. Ansible Roles & Playbook Structure (25 Marks)

| Criteria | Points | Verification |
|----------|--------|--------------|
| Proper use of roles (not single playbook) | 8 | Check `ansible/roles/` structure |
| Separate frontend/backend roles | 10 | Verify both roles exist and are used |
| Sensible defaults, handlers, templates | 7 | Review role contents |

**Self-Check:**
```bash
# Verify role structure
tree ansible/roles/

# Check playbook uses roles
grep -A5 "roles:" ansible/playbooks/site.yaml
```

### C. Nginx Frontend + Backend HTTPD Behavior (25 Marks)

| Criteria | Points | Verification |
|----------|--------|--------------|
| All 3 backends running HTTPD with distinct content | 8 | Test each backend individually |
| Nginx correctly reverse-proxying | 8 | Test frontend URL |
| Upstream 2 primary + 1 backup verified | 9 | Test failover behavior |

**Self-Check:**
```bash
# Test all backends
./test.sh

# Manual verification
for i in {1..10}; do curl -s http://<frontend-ip> | grep "Backend"; done
```

### D. Terraform–Ansible Automation & Idempotence (15 Marks)

| Criteria | Points | Verification |
|----------|--------|--------------|
| Ansible triggered from Terraform | 8 | Check `null_resource` in main.tf |
| Single `terraform apply` does everything | 4 | Test clean deployment |
| Re-running is idempotent | 3 | Run `terraform apply` twice |

**Self-Check:**
```bash
# Clean deployment test
terraform destroy -auto-approve
terraform apply -auto-approve
# Should complete without errors

# Idempotence test
terraform apply -auto-approve
# Should show "No changes" or minimal changes
```

### E. Code Quality, Documentation & Git Usage (10 Marks)

| Criteria | Points | Verification |
|----------|--------|--------------|
| Clear structure, comments, naming | 5 | Review all files |
| README with assumptions | 3 | Check README completeness |
| Clean Git history | 2 | Check for secrets/state files |

**Self-Check:**
```bash
# Check for sensitive files
git status --ignored

# Check git history
git log --oneline

# Verify gitignore works
git check-ignore -v .terraform *.tfstate
```

---

## 🎯 Final Verification Commands

Run these before submission:

```bash
# 1. Verify project structure
tree -L 3 -I 'node_modules|.terraform'

# 2. Check for sensitive files
find . -name "*.tfstate*" -o -name "*.pem" -o -name "id_rsa*"
# Should return nothing

# 3. Test clean deployment
terraform destroy -auto-approve
terraform apply -auto-approve

# 4. Verify functionality
./test.sh

# 5. Test idempotence
terraform apply -auto-approve
# Should complete with no changes

# 6. Check git status
git status
# Should not show .terraform/, *.tfstate, keys

# 7. Verify outputs
terraform output
```

---

## 📝 Common Deductions to Avoid

| Issue | Deduction | How to Avoid |
|-------|-----------|--------------|
| Not using roles | -20 marks | Use `ansible/roles/` structure |
| Manual ansible-playbook needed | -8 marks | Use `null_resource` with `local-exec` |
| No backup backend | -9 marks | Configure `backup` in upstream |
| Hard-coded IPs | -5 marks | Use variables and outputs |
| Committed secrets/state | -2 marks | Use proper `.gitignore` |
| No README | -3 marks | Document everything |
| Backends not distinct | -8 marks | Use templates with hostnames |

---

## 🚀 Quick Final Test

Before submission, run this complete test:

```bash
#!/bin/bash
echo "=== Final Submission Verification ==="

# 1. Clean slate
echo "1. Destroying existing infrastructure..."
terraform destroy -auto-approve

# 2. Fresh deployment
echo "2. Fresh deployment test..."
terraform init
terraform apply -auto-approve

# 3. Wait for services
echo "3. Waiting 60 seconds for all services..."
sleep 60

# 4. Test functionality
echo "4. Testing functionality..."
./test.sh

# 5. Idempotence check
echo "5. Idempotence test..."
terraform apply -auto-approve

# 6. Git check
echo "6. Git repository check..."
git status

echo "=== Verification Complete ==="
echo "If all tests passed, you're ready to submit!"
```

---

## 📤 Submission Preparation

1. **Final Git Commit:**
```bash
git add .
git commit -m "Final submission: Complete Terraform+Ansible lab project"
git push origin main
```

2. **Repository Name Format:**
```
CC_<YourName>_<YourRollNumber>/LabProject_FrontendBackend
```

3. **Include in Repository:**
   - All Terraform files
   - All Ansible files
   - Documentation (README, DEPLOYMENT, etc.)
   - Original lab document
   - `.gitignore` file

4. **DO NOT Include:**
   - `.terraform/` directory
   - `*.tfstate` files
   - SSH keys
   - AWS credentials
   - `terraform.tfvars` with sensitive data

---

## ✅ Submission Sign-off

Before final submission, confirm:

- [ ] Tested on clean AWS account/environment
- [ ] All tests pass successfully
- [ ] Documentation is complete and accurate
- [ ] No sensitive data committed
- [ ] Repository follows naming convention
- [ ] All required files present
- [ ] Roles properly structured
- [ ] Automation works end-to-end
- [ ] Idempotence verified
- [ ] Clean git history

**Submitted by:** [Your Name]  
**Roll Number:** [Your Roll Number]  
**Date:** [Submission Date]  
**Repository:** [GitHub Repository URL]

---

**Good luck! 🎓**
