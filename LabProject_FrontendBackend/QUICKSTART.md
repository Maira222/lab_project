# 🚀 Quick Start Guide

## For the Impatient (TL;DR)

```bash
# 1. Setup (one-time)
./setup.sh

# 2. Deploy everything
terraform apply -auto-approve

# 3. Test
./test.sh

# 4. Cleanup
terraform destroy -auto-approve
```

That's it! 🎉

---

## 5-Minute Deployment Guide

### Prerequisites Check (2 minutes)
```bash
# Check if you have everything
terraform --version  # Need v1.0+
ansible --version    # Need v2.9+
aws --version        # Need AWS CLI
aws sts get-caller-identity  # Check AWS access
```

### Deploy (3 minutes)

#### Option 1: Automated Setup
```bash
# Run setup script (handles prerequisites)
./setup.sh

# Deploy infrastructure + configure services
terraform apply -auto-approve
```

#### Option 2: Manual Steps
```bash
# Ensure SSH keys exist
ls ~/.ssh/id_rsa*

# Initialize Terraform
terraform init

# Deploy everything
terraform apply -auto-approve
```

### What Gets Created

After running `terraform apply -auto-approve`:

1. **AWS Infrastructure** (2 minutes):
   - 1 VPC with Internet Gateway
   - 1 Public Subnet
   - 1 Security Group
   - 4 EC2 Instances (t2.micro)

2. **Automatic Configuration** (2 minutes):
   - 3 Backend servers with Apache HTTPD
   - 1 Frontend server with Nginx
   - Load balancing configured
   - All services started

3. **Outputs Displayed**:
   - Frontend URL
   - All backend URLs
   - Test commands

---

## Common Quick Commands

### Get Frontend URL
```bash
terraform output frontend_url
# Or
echo "http://$(terraform output -raw frontend_public_ip)"
```

### Test Load Balancing
```bash
# Should alternate between backend-0 and backend-1
for i in {1..10}; do 
  curl -s http://$(terraform output -raw frontend_public_ip) | grep "Backend"
done
```

### Access a Server
```bash
# Frontend
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw frontend_public_ip)

# Backend-0
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -json backend_public_ips | jq -r '.[0]')
```

### Check Nginx Logs
```bash
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw frontend_public_ip) \
  "sudo tail -20 /var/log/nginx/access.log"
```

### Test Backup Failover
```bash
# Get backend IPs
BACKEND_0=$(terraform output -json backend_public_ips | jq -r '.[0]')
BACKEND_1=$(terraform output -json backend_public_ips | jq -r '.[1]')

# Stop primary backends
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 "sudo systemctl stop httpd"
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_1 "sudo systemctl stop httpd"

# Test - should serve from backup
curl http://$(terraform output -raw frontend_public_ip)

# Restart
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 "sudo systemctl start httpd"
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_1 "sudo systemctl start httpd"
```

---

## Troubleshooting Quick Fixes

### "Error: creating EC2 Instance"
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check region availability
aws ec2 describe-availability-zones --region us-east-1
```

### "Connection timeout" during Ansible
```bash
# Increase wait time in main.tf (change 30 to 60)
# Then re-apply
terraform apply -auto-approve
```

### "Permission denied (publickey)"
```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### Nginx returns 502
```bash
# Check backend status
BACKEND_0=$(terraform output -json backend_public_ips | jq -r '.[0]')
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 "sudo systemctl status httpd"

# Check Nginx error logs
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw frontend_public_ip) \
  "sudo tail -20 /var/log/nginx/error.log"
```

---

## Development Workflow

### Make Changes and Re-apply
```bash
# Edit Terraform or Ansible files
vim main.tf

# Apply changes (idempotent)
terraform apply -auto-approve

# Verify
./test.sh
```

### Test Ansible Changes Only
```bash
# Run Ansible playbook manually
cd ansible
ansible-playbook -i inventory/hosts playbooks/site.yaml
```

### View Current State
```bash
# Show all resources
terraform state list

# Show specific resource
terraform state show aws_instance.frontend

# Show outputs
terraform output
```

### Destroy Specific Resource
```bash
# Destroy and recreate one instance
terraform destroy -target=aws_instance.backend[0]
terraform apply -target=aws_instance.backend[0]
```

---

## Verification Checklist

Before considering your deployment successful:

- [ ] `terraform output` shows all IPs
- [ ] Frontend URL loads in browser
- [ ] All 3 backend URLs load individually
- [ ] Load balancing alternates between backend-0 and backend-1
- [ ] Backup failover works (test manually)
- [ ] Nginx logs show traffic distribution
- [ ] `terraform apply` is idempotent (no changes on re-run)
- [ ] All services survive instance reboot

### Quick Verification
```bash
# Automated checks
./test.sh

# Manual browser test
firefox $(terraform output -raw frontend_url) &

# Check if idempotent
terraform apply -auto-approve
# Should show: "No changes. Your infrastructure matches the configuration."
```

---

## Cost Management

### Check Current Resources
```bash
# List all EC2 instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Estimated Costs (us-east-1, t2.micro)
- **4 instances × $0.0116/hour = $0.046/hour**
- **Per day: ~$1.11**
- **Per month: ~$33.41**

### Stop Instances (saves $, keeps config)
```bash
# Stop all instances
aws ec2 stop-instances --instance-ids \
  $(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=lab-*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)
```

### Destroy Everything (removes all)
```bash
terraform destroy -auto-approve
```

---

## Production Checklist (Beyond Lab)

If you want to make this production-ready:

- [ ] Use private subnets for backends
- [ ] Add NAT Gateway for backend internet access
- [ ] Implement SSL/TLS (port 443)
- [ ] Use Auto Scaling Groups
- [ ] Add Application Load Balancer (ALB)
- [ ] Implement health checks
- [ ] Add CloudWatch monitoring
- [ ] Set up log aggregation
- [ ] Use Route53 for DNS
- [ ] Implement backup strategy
- [ ] Add database tier
- [ ] Use Secrets Manager for credentials
- [ ] Implement CI/CD pipeline
- [ ] Add WAF (Web Application Firewall)
- [ ] Use multiple AZs for HA

---

## Useful One-Liners

```bash
# Get all public IPs
terraform output -json | jq '.[]|.value' | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'

# Test all backends
for ip in $(terraform output -json backend_public_ips | jq -r '.[]'); do 
  echo "Testing $ip:"; curl -s http://$ip | grep Backend; echo
done

# Watch Nginx logs in real-time
watch -n 1 "curl -s http://$(terraform output -raw frontend_public_ip) | grep Backend"

# Count requests per backend
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw frontend_public_ip) \
  "sudo awk '{print \$NF}' /var/log/nginx/access.log | sort | uniq -c"

# Restart all backend services
for ip in $(terraform output -json backend_public_ips | jq -r '.[]'); do
  ssh -i ~/.ssh/id_rsa ec2-user@$ip "sudo systemctl restart httpd"
done

# Check all service statuses
for ip in $(terraform output -json backend_public_ips | jq -r '.[]'); do
  echo "Backend $ip:"; 
  ssh -i ~/.ssh/id_rsa ec2-user@$ip "sudo systemctl is-active httpd"
done
```

---

## Video Demo Script (For Recording)

```bash
# 1. Show clean state
terraform destroy -auto-approve

# 2. Deploy
time terraform apply -auto-approve

# 3. Show outputs
terraform output

# 4. Test load balancing
for i in {1..10}; do 
  curl -s http://$(terraform output -raw frontend_public_ip) | grep "Backend server"
done

# 5. Test individual backends
for ip in $(terraform output -json backend_public_ips | jq -r '.[]'); do
  echo "Testing $ip:"; curl -s http://$ip | grep "Backend server"
done

# 6. Test failover
BACKEND_0=$(terraform output -json backend_public_ips | jq -r '.[0]')
BACKEND_1=$(terraform output -json backend_public_ips | jq -r '.[1]')
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 "sudo systemctl stop httpd"
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_1 "sudo systemctl stop httpd"
curl http://$(terraform output -raw frontend_public_ip)

# 7. Restore
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 "sudo systemctl start httpd"
ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_1 "sudo systemctl start httpd"

# 8. Test idempotence
terraform apply -auto-approve

# 9. Cleanup
terraform destroy -auto-approve
```

---

## Remember

1. **Always destroy after testing** to avoid charges:
   ```bash
   terraform destroy -auto-approve
   ```

2. **This is for learning** - Production needs more security and HA features

3. **Check your AWS bill** regularly

4. **Keep credentials secure** - Never commit to Git

---

## Quick Reference Links

- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Ansible Docs**: https://docs.ansible.com/
- **Nginx Docs**: http://nginx.org/en/docs/
- **AWS Free Tier**: https://aws.amazon.com/free/

---

## Support

Having issues? Check these in order:

1. Run `./setup.sh` to verify prerequisites
2. Check `DEPLOYMENT.md` for detailed troubleshooting
3. Review `CHECKLIST.md` for common issues
4. Look at AWS Console for resource status
5. Check Terraform output for error messages

Good luck! 🎓
