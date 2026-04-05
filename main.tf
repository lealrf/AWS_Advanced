# ==========================================
# 1. NETWORKING (VPC & Subnets)
# ==========================================
resource "aws_vpc" "finguard_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "finguard_igw" {
  vpc_id = aws_vpc.finguard_vpc.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.finguard_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.finguard_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.finguard_igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# 2. SECURITY & COMPLIANCE (KMS & S3)
# ==========================================
# KMS Key for encrypting financial data at rest (PCI DSS requirement)
resource "aws_kms_key" "finguard_key" {
  description             = "KMS key for encrypting FinGuard transaction logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# S3 Bucket for Transaction Logs
resource "aws_s3_bucket" "tx_logs" {
  bucket_prefix = "finguard-tx-logs-"
}

# Enforce KMS Encryption on S3
resource "aws_s3_bucket_server_side_encryption_configuration" "secure_logs" {
  bucket = aws_s3_bucket.tx_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.finguard_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block Public Access to Financial Logs
resource "aws_s3_bucket_public_access_block" "secure_access" {
  bucket                  = aws_s3_bucket.tx_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==========================================
# 3. COMPUTE & WORKING SYSTEM (EC2 + Docker)
# ==========================================
resource "aws_security_group" "app_sg" {
  name        = "finguard_app_sg"
  description = "Allow HTTP for API and SSH for Admin"
  vpc_id      = aws_vpc.finguard_vpc.id

  ingress {
    description = "HTTP Traffic (Simulating ALB)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks =["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks =["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values =["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro" # Free Tier eligible in eu-central-1
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids =[aws_security_group.app_sg.id]

  # This script creates the Docker container and Nginx proxy automatically
  user_data = <<-EOF
              #!/bin/bash
              # Update and install dependencies
              dnf update -y
              dnf install docker nginx -y
              systemctl start docker
              systemctl enable docker

              # Create application directory
              mkdir -p /opt/finguard
              cd /opt/finguard

              # 1. Create the Python API application
              cat << 'APP' > app.py
              from flask import Flask, jsonify
              app = Flask(__name__)
              
              @app.route('/health')
              def health(): 
                  return jsonify({"status": "healthy", "service": "FinGuard API", "compliance": "PCI-DSS-PoC"}), 200
              
              if __name__ == '__main__': 
                  app.run(host='0.0.0.0', port=8080)
              APP

              # 2. Create the Dockerfile
              cat << 'DOCKER' > Dockerfile
              FROM python:3.9-slim
              WORKDIR /app
              COPY app.py .
              RUN pip install flask
              EXPOSE 8080
              CMD ["python", "app.py"]
              DOCKER

              # 3. Build and Run the Container
              docker build -t finguard-api .
              docker run -d -p 8080:8080 --restart always --name finguard-app finguard-api

              # 4. Configure Nginx as Reverse Proxy (Simulating our ALB)
              cat << 'NGINX' > /etc/nginx/conf.d/finguard.conf
              server {
                  listen 80;
                  server_name _;
                  location / {
                      proxy_pass http://127.0.0.1:8080;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                  }
              }
              NGINX
              
              # Restart Nginx to apply changes
              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "FinGuard-App-Server"
  }
}