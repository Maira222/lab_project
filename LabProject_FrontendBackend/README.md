# Lab Project: Terraform + Ansible - Nginx Frontend with 3 Backend HTTPD Servers (HA + Auto-Config)

## 📋 Project Overview

This project demonstrates a complete Infrastructure as Code (IaC) solution that:
- Creates a multi-tier AWS architecture using **Terraform**
- Configures servers automatically using **Ansible roles**
- Implements a High Availability (HA) load balancer setup with Nginx
- Supports backup failover for backend servers

## 🏗️ Architecture

```
                    Internet
                       |
                       ↓
                  [Internet Gateway]
                       |
                       ↓
                   [VPC: 10.0.0.0/16]
                       |
            ┌──────────┴──────────┐
            ↓                     ↓
    [Frontend Nginx]      [3 Backend HTTPD]
    Load Balancer         - Backend-0 (Primary)
    - Port 80             - Backend-1 (Primary)
    - Reverse Proxy       - Backend-2 (Backup)
```

### Components

1. **Frontend Server (Nginx)**
   - Acts as reverse proxy and load balancer
   - Distributes traffic between 2 primary backends
   - Automatically fails over to backup backend

2. **Backend Servers (Apache HTTPD)**
   - 3 independent HTTPD servers
   - Each serves unique content for identification
   - 2 configured as primary, 1 as backup

3. **Load Balancing Strategy**
   - Round-robin between 2 primary backends
   - Backup server activates only when primaries fail
   - Health checks and automatic failover

## 📁 Project Structure

```
LabProject_FrontendBackend/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── locals.tf                    # Local variables
├── templates/
│   ├── hosts.tpl               # Ansible inventory template
│   └── extra_vars.tpl          # Ansible variables template
├── ansible/
│   ├── ansible.cfg             # Ansible configuration
│   ├── inventory/              # (Generated dynamically)
│   ├── playbooks/
│   │   └── site.yaml           # Main playbook
│   └── roles/
│       ├── backend/            # Backend HTTPD role
│       │   ├── tasks/
│       │   │   └── main.yml
│       │   ├── handlers/
│       │   │   └── main.yml
│       │   └── templates/
│       │       └── backend_index.html.j2
│       └── frontend/           # Frontend Nginx role
│           ├── tasks/
│           │   └── main.yml
│           ├── handlers/
│           │   └── main.yml
│           └── templates/
│               └── nginx_frontend.conf.j2
├── .gitignore
└── README.md
```

## 🚀 Prerequisites

### Required Software
- Terraform (>= 1.0)
- Ansible (>= 2.9)
- AWS CLI configured with credentials
- SSH key pair

### AWS Requirements
- AWS account with appropriate permissions
- EC2, VPC, and networking permissions
- Default region: us-east-1 (configurable)

### SSH Keys
Generate an SSH key pair if you don't have one:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

## 📦 Installation & Setup

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd LabProject_FrontendBackend
```

### 2. Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and preferred region
```

### 3. Verify SSH Keys
Ensure your SSH keys exist:
```bash
ls -la ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
```

### 4. Initialize Terraform
```bash
terraform init
```

## 🎯 Usage

### Deploy the Infrastructure

Run the following single command to:
- Create all AWS resources (VPC, subnets, security groups, EC2 instances)
- Automatically configure all servers with Ansible
- Set up Nginx load balancer with backend servers

```bash
terraform apply -auto-approve
```

**What happens during deployment:**
1. Terraform creates AWS infrastructure
2. Waits 30 seconds for instances to be ready
3. Generates Ansible inventory dynamically
4. Runs Ansible playbooks automatically
5. Configures Nginx and HTTPD services

### View Outputs

After successful deployment:
```bash
terraform output
```

You'll see:
- Frontend public IP and URL
- All backend public/private IPs
- Test commands for verification

### Testing the Setup

#### Test Load Balancing (Round-Robin between Primary Backends)
```bash
# Get frontend IP
FRONTEND_IP=$(terraform output -raw frontend_public_ip)

# Send 10 requests - should alternate between backend-0 and backend-1
for i in {1..10}; do
  curl -s http://$FRONTEND_IP | grep "Backend server"
done
```

#### Test Individual Backends
```bash
# Test backend-0
curl http://$(terraform output -json backend_public_ips | jq -r '.[0]')

# Test backend-1
curl http://$(terraform output -json backend_public_ips | jq -r '.[1]')

# Test backend-2 (backup)
curl http://$(terraform output -json backend_public_ips | jq -r '.[2]')
```

#### Test Backup Failover

1. **Stop primary backends:**
```bash
# SSH to backend-0 and stop HTTPD
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -json backend_public_ips | jq -r '.[0]') \
  "sudo systemctl stop httpd"

# SSH to backend-1 and stop HTTPD
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -json backend_public_ips | jq -r '.[1]') \
  "sudo systemctl stop httpd"
```

2. **Test frontend - should now serve from backup (backend-2):**
```bash
curl http://$FRONTEND_IP
```

3. **Restart primary backends:**
```bash
ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -json backend_public_ips | jq -r '.[0]') \
  "sudo systemctl start httpd"

ssh -i ~/.ssh/id_rsa ec2-user@$(terraform output -json backend_public_ips | jq -r '.[1]') \
  "sudo systemctl start httpd"
```

### Verify Nginx Logs

SSH to frontend and check logs:
```bash
ssh -i ~/.ssh/id_rsa ec2-user@$FRONTEND_IP
sudo tail -f /var/log/nginx/access.log
```

The logs show which backend served each request.

## 🔄 Idempotence Test

Re-running Terraform should make no changes:
```bash
terraform plan
# Should show: "No changes. Your infrastructure matches the configuration."

terraform apply -auto-approve
# Should complete without errors and show no changes
```

## 🧹 Cleanup

Destroy all resources when done:
```bash
terraform destroy -auto-approve
```

## ⚙️ Configuration

### Customizing Variables

Create a `terraform.tfvars` file (optional):
```hcl
aws_region         = "us-east-1"
env_prefix         = "lab"
instance_type      = "t2.micro"
vpc_cidr_block     = "10.0.0.0/16"
subnet_cidr_block  = "10.0.1.0/24"
availability_zone  = "us-east-1a"
public_key         = "~/.ssh/id_rsa.pub"
private_key        = "~/.ssh/id_rsa"
```

### Nginx Configuration

The Nginx upstream configuration in `nginx_frontend.conf.j2`:
```nginx
upstream backend_servers {
    server <backend-0-private-ip>:80;      # Primary
    server <backend-1-private-ip>:80;      # Primary
    server <backend-2-private-ip>:80 backup; # Backup only
}
```

## 📊 Key Features Demonstrated

### Terraform
✅ VPC, subnet, Internet Gateway, Route Table  
✅ Security Groups with least-privilege access  
✅ EC2 instance provisioning with tags  
✅ Dynamic inventory generation  
✅ Terraform-Ansible integration via null_resource  
✅ Idempotent infrastructure  

### Ansible
✅ Proper role-based structure  
✅ Separate frontend and backend roles  
✅ Jinja2 templates for dynamic configuration  
✅ Handlers for service management  
✅ Automated deployment without manual intervention  

### High Availability
✅ Load balancing across multiple backends  
✅ Primary/backup failover configuration  
✅ Health checks and automatic recovery  
✅ Distinct content per backend for verification  

## 🐛 Troubleshooting

### Issue: Terraform can't find SSH keys
**Solution:** Ensure keys exist at specified paths or update variables.tf

### Issue: Ansible connection timeout
**Solution:** Wait longer for instances to be ready or increase sleep time in null_resource

### Issue: Nginx can't reach backends
**Solution:** Verify security group allows traffic within VPC CIDR

### Issue: Permission denied during Ansible execution
**Solution:** Verify SSH key permissions: `chmod 600 ~/.ssh/id_rsa`

### Issue: AMI not found
**Solution:** Change AWS region or update AMI filter in main.tf

## 📝 Assumptions

1. **AWS Region:** Default is us-east-1
2. **Instance Type:** t2.micro (free tier eligible)
3. **AMI:** Latest Amazon Linux 2 (auto-selected)
4. **SSH Keys:** Expected at ~/.ssh/id_rsa
5. **Network:** Creates new VPC (10.0.0.0/16)
6. **Ports:** HTTP (80) open to internet, SSH restricted to your IP

## 🎓 Learning Outcomes Achieved

✅ Design multi-tier AWS architecture with Terraform  
✅ Use Ansible roles for separation of concerns  
✅ Configure Nginx as reverse proxy with HA  
✅ Implement primary/backup backend strategy  
✅ Automate infrastructure + configuration in single command  
✅ Demonstrate idempotent operations  
✅ Follow production-like project structure  

## 📚 References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Nginx Upstream Module](http://nginx.org/en/docs/http/ngx_http_upstream_module.html)
- [Apache HTTPD Documentation](https://httpd.apache.org/docs/)

## 👤 Author

**Name:** [Your Name]  
**Roll Number:** [Your Roll Number]  
**Repository:** CC_<YourName>_<YourRollNumber>/LabProject_FrontendBackend

## 📄 License

This project is for educational purposes as part of a Cloud Computing lab assignment.

---

**Note:** Remember to destroy resources after testing to avoid AWS charges:
```bash
terraform destroy -auto-approve
```
