#!/bin/bash

# Deploy to AWS EC2 or Elastic Beanstalk
# These have reliable DNS that works globally

echo "Deploying to AWS..."

# Option 1: Deploy to AWS Elastic Beanstalk (Easiest)
# 1. Install EB CLI: pip install awsebcli
# 2. Initialize: eb init -p node.js parkease-backend
# 3. Create environment: eb create parkease-production
# 4. Deploy: eb deploy

# Option 2: Deploy to AWS EC2 with PM2
# 1. Launch EC2 instance (t2.micro for free tier)
# 2. Install Node.js and PM2
# 3. Clone repository
# 4. Run with PM2: pm2 start server.js --name parkease

# Option 3: Use AWS App Runner (Serverless)
# Automatic scaling, no server management needed

echo "AWS deployment provides:"
echo "- Reliable global DNS"
echo "- Better uptime (99.99% SLA)"
echo "- Elastic Load Balancing"
echo "- Auto-scaling"
echo "- CloudFront CDN for global distribution"