# 🚀 Deployment Guide

## Quick Start

### 1. Initial Setup (One-time)

```bash
# Ensure you have AWS credentials configured
aws configure

# Generate SSH keys if you don't have them
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Verify keys exist
ls -la ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
```

### 2. Deploy Everything

```bash
# Initialize Terraform
terraform init

# Deploy infrastructure and configure all services
terraform apply -auto-approve
```

**That's it!** One command deploys everything:
- ✅ VPC, subnets, security groups
- ✅ 1 frontend + 3 backend EC2 instances
- ✅ Nginx load balancer configuration
- ✅ Apache HTTPD on all backends

### 3. Test the Deployment

```bash
# Run the automated test suite
./test.sh

# Or manually test the frontend
curl http://$(terraform output -raw frontend_public_ip)
```

### 4. View Results

```bash
# See all outputs
terraform output

# Access frontend in browser
terraform output frontend_url
```

## Detailed Deployment Steps

### Step 1: Pre-deployment Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform installed (v1.0+)
- [ ] Ansible installed (v2.9+)
- [ ] SSH key pair exists
- [ ] AWS credentials have required permissions

### Step 2: Configuration Review

Optional: Customize `terraform.tfvars.example` and save as `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"      # Your preferred region
instance_type = "t2.micro"       # Instance size
env_prefix    = "lab"            # Resource name prefix
```

### Step 3: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 4: Preview Changes

```bash
terraform plan
```

Review the plan to see what will be created:
- 1 VPC
- 1 Internet Gateway
- 1 Subnet
- 1 Route Table
- 1 Security Group
- 1 Key Pair
- 4 EC2 Instances (1 frontend + 3 backends)
- Supporting resources

### Step 5: Deploy Infrastructure

```bash
terraform apply -auto-approve
```

**What happens:**
1. Creates AWS resources (~2 minutes)
2. Waits 30 seconds for instances to boot
3. Generates Ansible inventory
4. Runs Ansible playbooks (~2 minutes)
5. Configures Nginx and HTTPD

Total time: ~5 minutes

### Step 6: Verify Deployment

```bash
# Check outputs
terraform output

# Test frontend
FRONTEND_IP=$(terraform output -raw frontend_public_ip)
curl http://$FRONTEND_IP

# Run full test suite
./test.sh
```

## Understanding the Output

After successful deployment, you'll see:

```hcl
Outputs:

backend_private_ips = [
  "10.0.1.XXX",
  "10.0.1.YYY",
  "10.0.1.ZZZ",
]
backend_public_ips = [
  "XX.XXX.XX.XX",
  "YY.YYY.YY.YY",
  "ZZ.ZZZ.ZZ.ZZ",
]
frontend_public_ip = "AA.AAA.AA.AA"
frontend_url = "http://AA.AAA.AA.AA"
```

## Testing Scenarios

### Scenario 1: Normal Load Balancing

```bash
# Send multiple requests
for i in {1..10}; do
  curl -s http://$(terraform output -raw frontend_public_ip) | grep "Backend server"
done
```

**Expected:** Alternates between backend-0 and backend-1

### Scenario 2: Backup Failover

```bash
# Get backend IPs
B0=$(terraform output -json backend_public_ips | jq -r '.[0]')
B1=$(terraform output -json backend_public_ips | jq -r '.[1]')

# Stop primary backends
ssh -i ~/.ssh/id_rsa ec2-user@$B0 "sudo systemctl stop httpd"
ssh -i ~/.ssh/id_rsa ec2-user@$B1 "sudo systemctl stop httpd"

# Test - should now serve from backend-2
curl http://$(terraform output -raw frontend_public_ip)

# Restart backends
ssh -i ~/.ssh/id_rsa ec2-user@$B0 "sudo systemctl start httpd"
ssh -i ~/.ssh/id_rsa ec2-user@$B1 "sudo systemctl start httpd"
```

**Expected:** Requests served by backend-2 when primaries are down

### Scenario 3: Check Nginx Logs

```bash
# SSH to frontend
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -raw frontend_public_ip)

# View access logs
sudo tail -f /var/log/nginx/access.log
```

**Expected:** Logs show which backend served each request

## Troubleshooting

### Issue: "Error: creating EC2 Instance"

**Cause:** Insufficient AWS permissions or service limits  
**Solution:** 
- Check AWS credentials: `aws sts get-caller-identity`
- Verify EC2 instance limits in AWS Console
- Ensure region supports chosen instance type

### Issue: "Connection timeout" during Ansible

**Cause:** Instances not fully ready or security group blocking  
**Solution:**
- Increase sleep time in `null_resource` (from 30 to 60 seconds)
- Verify security group allows SSH from your IP
- Check AWS Console for instance status

### Issue: "Could not find resource"

**Cause:** AMI not available in selected region  
**Solution:**
- Change `aws_region` variable
- Or update AMI filter in `main.tf`

### Issue: Nginx returns 502 Bad Gateway

**Cause:** Backends not running or misconfigured  
**Solution:**
- SSH to backend: `ssh -i ~/.ssh/id_rsa ec2-user@<backend-ip>`
- Check HTTPD status: `sudo systemctl status httpd`
- Check Nginx error logs: `sudo tail -20 /var/log/nginx/error.log`

### Issue: Permission denied (publickey)

**Cause:** SSH key issues  
**Solution:**
```bash
# Fix permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Verify key path matches variables
grep private_key variables.tf
```

## Re-deployment (Idempotence Test)

```bash
# Should show no changes
terraform plan

# Should complete without errors
terraform apply -auto-approve
```

**Expected:** "No changes" or only minor timing-based changes

## Cleanup

```bash
# Destroy all resources
terraform destroy -auto-approve
```

**Warning:** This is irreversible! All data will be lost.

## Cost Considerations

Using default settings (t2.micro instances in us-east-1):
- **Estimated cost:** ~$0.02/hour for all 4 instances
- **Daily cost:** ~$0.50
- **Monthly cost:** ~$15

**Recommendation:** Destroy resources when not in use.

## Best Practices

1. **Always destroy after testing:**
   ```bash
   terraform destroy -auto-approve
   ```

2. **Never commit sensitive files:**
   - `.gitignore` is configured to exclude keys and state files
   - Double-check before pushing: `git status`

3. **Use separate environments:**
   - Development: `env_prefix = "dev"`
   - Testing: `env_prefix = "test"`
   - Production: Use Terraform workspaces

4. **Version control:**
   - Commit infrastructure code
   - Don't commit: state files, keys, .terraform/

## Next Steps

After successful deployment:

1. **Experiment with configuration:**
   - Modify Nginx upstream settings
   - Add more backends
   - Implement SSL/TLS

2. **Enhance monitoring:**
   - Add CloudWatch metrics
   - Set up log aggregation
   - Create dashboards

3. **Improve automation:**
   - Add CI/CD pipeline
   - Implement automated testing
   - Add backup strategies

4. **Scale the architecture:**
   - Use Auto Scaling Groups
   - Add database tier
   - Implement caching layer

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Terraform/Ansible output logs
3. Verify AWS Console for resource status
4. Check security group and network configuration

---

**Remember:** Always run `terraform destroy -auto-approve` after testing to avoid unnecessary AWS charges!
