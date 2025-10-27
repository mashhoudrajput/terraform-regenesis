resource "aws_key_pair" "ssh" {
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)
}

resource "aws_instance" "bastion" {
  ami                         = local.effective_ami
  instance_type               = var.bastion_instance_type
  subnet_id                   = element(values(aws_subnet.public), 0).id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "${local.environment}-${local.service}-bastion-${local.region}" }
}

resource "aws_instance" "app" {
  ami                         = local.effective_ami
  instance_type               = var.app_instance_type
  subnet_id                   = element(values(aws_subnet.private), 0).id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.ssh.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Wait for internet connectivity (NAT Gateway to be ready)
              echo "Waiting for internet connectivity..."
              for i in {1..30}; do
                if ping -c 1 8.8.8.8 &>/dev/null; then
                  echo "Internet connectivity established"
                  break
                fi
                echo "Attempt $i: Waiting for internet..."
                sleep 10
              done
              
              # Update system
              apt-get update -y
              
              # Install prerequisites
              apt-get install -y unzip curl
              
              # Install AWS CLI v2
              cd /tmp
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              ./aws/install
              rm -rf aws awscliv2.zip
              cd /root
              
              # Install Docker
              apt-get install -y ca-certificates gnupg lsb-release
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              systemctl enable docker
              systemctl start docker
              
              # Add ubuntu user to docker group
              usermod -aG docker ubuntu
              
              # Install Python (for test server)
              apt-get install -y python3 python3-pip
              
              # Create test app
              mkdir -p /var/www/html
              cat <<EOM >/var/www/html/index.html
              Hello from ${local.environment}-${local.service}-api - AWS CLI and Docker installed
              EOM
              
              # Create 4GB swap
              fallocate -l 4G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab
              
              # Start test server
              nohup python3 -m http.server 3000 --directory /var/www/html 1>/var/log/app.log 2>&1 &
              EOF

  tags       = { Name = "${local.environment}-${local.service}-app-${local.region}" }
  depends_on = [aws_nat_gateway.nat, aws_route.private_to_nat]
}

resource "aws_instance" "app2" {
  count                       = var.create_app2 ? 1 : 0
  ami                         = local.effective_ami
  instance_type               = var.app_instance_type
  subnet_id                   = element(values(aws_subnet.private), 1).id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.ssh.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Wait for internet connectivity (NAT Gateway to be ready)
              echo "Waiting for internet connectivity..."
              for i in {1..30}; do
                if ping -c 1 8.8.8.8 &>/dev/null; then
                  echo "Internet connectivity established"
                  break
                fi
                echo "Attempt $i: Waiting for internet..."
                sleep 10
              done
              
              # Update system
              apt-get update -y
              
              # Install prerequisites
              apt-get install -y unzip curl
              
              # Install AWS CLI v2
              cd /tmp
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              ./aws/install
              rm -rf aws awscliv2.zip
              cd /root
              
              # Install Docker
              apt-get install -y ca-certificates gnupg lsb-release
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              systemctl enable docker
              systemctl start docker
              
              # Add ubuntu user to docker group
              usermod -aG docker ubuntu
              
              # Install Python (for test server)
              apt-get install -y python3 python3-pip
              
              # Create test app
              mkdir -p /var/www/html
              cat <<EOM >/var/www/html/index.html
              Hello from ${local.environment}-${local.service}-queue - AWS CLI and Docker installed
              EOM
              
              # Create 4GB swap
              fallocate -l 4G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab
              
              # Start test server
              nohup python3 -m http.server 3000 --directory /var/www/html 1>/var/log/app.log 2>&1 &
              EOF

  tags       = { Name = "${local.environment}-${local.service}-queue-${local.region}" }
  depends_on = [aws_nat_gateway.nat, aws_route.private_to_nat]
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  tags     = { Name = "${local.environment}-${local.service}-bastion-eip-${local.region}" }
}

resource "aws_lb" "alb" {
  name               = "${local.environment}-${local.service}-alb-${local.region}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = { Name = "${local.environment}-${local.service}-alb-${local.region}" }
}

resource "aws_lb_target_group" "tg" {
  name     = "${local.environment}-${local.service}-tg-${local.region}"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${local.environment}-${local.service}-tg-${local.region}" }
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  # Only API server is attached to ALB, queue server handles background jobs
  target_id = aws_instance.app.id
  port      = 3000
}

# Queue server (app2) is NOT attached to ALB - it handles background processing only
# resource "aws_lb_target_group_attachment" "attach_app2" {
#   count            = var.create_app2 ? 1 : 0
#   target_group_arn = aws_lb_target_group.tg.arn
#   target_id        = aws_instance.app2[0].id
#   port             = 3000
# }

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
