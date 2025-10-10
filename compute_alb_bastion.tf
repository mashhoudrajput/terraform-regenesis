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

  tags = { Name = "${local.name_prefix}-bastion" }
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
              apt-get update -y
              apt-get install -y python3 python3-pip
              mkdir -p /var/www/html
              cat <<EOM >/var/www/html/index.html
              Hello from ${local.name_prefix} - simple app listening on 3000
              EOM
              # create 4GB swap
              fallocate -l 4G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              nohup python3 -m http.server 3000 --directory /var/www/html 1>/var/log/app.log 2>&1 &
              EOF

  tags       = { Name = "${local.name_prefix}-app" }
  depends_on = [aws_iam_instance_profile.ec2_profile]
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
              apt-get update -y
              apt-get install -y python3 python3-pip
              mkdir -p /var/www/html
              cat <<EOM >/var/www/html/index.html
              Hello from ${local.name_prefix} - simple app listening on 3000 (queue)
              EOM
              # create 4GB swap
              fallocate -l 4G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              nohup python3 -m http.server 3000 --directory /var/www/html 1>/var/log/app.log 2>&1 &
              EOF

  tags       = { Name = "${local.name_prefix}-queue" }
  depends_on = [aws_iam_instance_profile.ec2_profile]
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  tags     = { Name = "${local.name_prefix}-bastion-eip" }
}

resource "aws_lb" "alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = { Name = "${local.name_prefix}-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "${local.name_prefix}-tg"
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

  tags = { Name = "${local.name_prefix}-tg" }
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  # attach both app instances to the target group
  target_id = aws_instance.app.id
  port      = 3000
}

resource "aws_lb_target_group_attachment" "attach_app2" {
  count            = var.create_app2 ? 1 : 0
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app2[0].id
  port             = 3000
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
