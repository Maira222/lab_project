#!/bin/bash
# Test script for verifying Nginx load balancer and backend setup

set -e

echo "================================================"
echo "Load Balancer and Backend Test Script"
echo "================================================"
echo ""

# Get IPs from Terraform output
echo "📋 Getting IP addresses from Terraform..."
FRONTEND_IP=$(terraform output -raw frontend_public_ip 2>/dev/null)
BACKEND_IPS=$(terraform output -json backend_public_ips 2>/dev/null | jq -r '.[]')

if [ -z "$FRONTEND_IP" ]; then
    echo "❌ Error: Could not get frontend IP. Is the infrastructure deployed?"
    exit 1
fi

echo "✅ Frontend IP: $FRONTEND_IP"
echo ""

# Test 1: Load Balancing
echo "🔄 Test 1: Testing load balancing (10 requests)..."
echo "Expected: Responses should alternate between backend-0 and backend-1"
echo "-----------------------------------------------------------"
for i in {1..10}; do
    RESPONSE=$(curl -s http://$FRONTEND_IP | grep -o "backend-[0-9]" | head -1)
    echo "Request $i: Served by $RESPONSE"
done
echo ""

# Test 2: Individual Backend Access
echo "🔍 Test 2: Testing individual backend servers..."
echo "-----------------------------------------------------------"
COUNT=0
for IP in $BACKEND_IPS; do
    echo "Testing Backend-$COUNT at $IP..."
    RESPONSE=$(curl -s http://$IP | grep -o "backend-[0-9]" | head -1)
    echo "  Response: $RESPONSE"
    COUNT=$((COUNT + 1))
done
echo ""

# Test 3: Health Check
echo "💚 Test 3: Testing Nginx health endpoint..."
echo "-----------------------------------------------------------"
HEALTH=$(curl -s http://$FRONTEND_IP/health)
echo "$HEALTH"
echo ""

# Test 4: Response Time
echo "⏱️  Test 4: Measuring response times..."
echo "-----------------------------------------------------------"
for i in {1..3}; do
    TIME=$(curl -o /dev/null -s -w '%{time_total}' http://$FRONTEND_IP)
    echo "Request $i: ${TIME}s"
done
echo ""

# Instructions for failover test
echo "🔧 Test 5: Manual Failover Test Instructions"
echo "-----------------------------------------------------------"
echo "To test backup failover, run these commands:"
echo ""
echo "1. Stop primary backends:"
BACKEND_0=$(echo $BACKEND_IPS | awk '{print $1}')
BACKEND_1=$(echo $BACKEND_IPS | awk '{print $2}')
echo "   ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 'sudo systemctl stop httpd'"
echo "   ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_1 'sudo systemctl stop httpd'"
echo ""
echo "2. Test frontend (should serve from backup - backend-2):"
echo "   curl http://$FRONTEND_IP"
echo ""
echo "3. Restart primary backends:"
echo "   ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_0 'sudo systemctl start httpd'"
echo "   ssh -i ~/.ssh/id_rsa ec2-user@$BACKEND_1 'sudo systemctl start httpd'"
echo ""

# Nginx logs check
echo "📊 To view Nginx access logs:"
echo "-----------------------------------------------------------"
echo "ssh -i ~/.ssh/id_rsa ec2-user@$FRONTEND_IP 'sudo tail -20 /var/log/nginx/access.log'"
echo ""

echo "================================================"
echo "✅ All automated tests completed!"
echo "================================================"
