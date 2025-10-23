resource "tls_private_key" "jump" {
  algorithm = "ED25519"
}

resource "aws_ssm_document" "write_private_key" {
  name          = "write-jump-private-key-${local.environment}-${local.service}-${local.region}"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Write private SSH key to bastion for jump usage"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "writeKey"
        inputs = {
          runCommand = [
            "mkdir -p /home/ubuntu/.ssh",
            "chmod 700 /home/ubuntu/.ssh",
            "cat > /home/ubuntu/.ssh/id_ed25519 <<'KEY'",
            tls_private_key.jump.private_key_openssh,
            "KEY",
            "chmod 600 /home/ubuntu/.ssh/id_ed25519",
            "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_ed25519"
          ]
        }
      }
    ]
  })
  depends_on = [aws_iam_instance_profile.ec2_profile]
}

resource "aws_ssm_document" "append_public_key" {
  name          = "append-jump-public-key-${local.environment}-${local.service}-${local.region}"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Append jump public key to app authorized_keys"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "appendKey"
        inputs = {
          runCommand = [
            "mkdir -p /home/ubuntu/.ssh",
            "chmod 700 /home/ubuntu/.ssh",
            "pub='${replace(tls_private_key.jump.public_key_openssh, "'", "'\\''")}'",
            "grep -qxF \"$pub\" /home/ubuntu/.ssh/authorized_keys || echo \"$pub\" >> /home/ubuntu/.ssh/authorized_keys",
            "chmod 600 /home/ubuntu/.ssh/authorized_keys",
            "chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys"
          ]
        }
      }
    ]
  })
  depends_on = [aws_iam_instance_profile.ec2_profile]
}

resource "aws_ssm_association" "deploy_private_to_bastion" {
  name = aws_ssm_document.write_private_key.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.bastion.id]
  }
}

resource "aws_ssm_association" "deploy_public_to_app" {
  name = aws_ssm_document.append_public_key.name
  targets {
    key    = "InstanceIds"
    values = concat([aws_instance.app.id], var.create_app2 ? [aws_instance.app2[0].id] : [])
  }
}

# SSH Config with aliases for bastion
resource "aws_ssm_document" "ssh_config" {
  name          = "ssh-config-${local.environment}-${local.service}-${local.region}"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Create SSH config with aliases on bastion"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "createSSHConfig"
        inputs = {
          runCommand = [
            "cat > /home/ubuntu/.ssh/config <<'EOF'",
            "# SSH aliases for internal servers",
            "",
            "Host api",
            "    HostName ${aws_instance.app.private_ip}",
            "    User ubuntu",
            "    IdentityFile ~/.ssh/id_ed25519",
            "    StrictHostKeyChecking no",
            "    UserKnownHostsFile /dev/null",
            "",
            var.create_app2 ? "Host queue" : "# Queue server not enabled",
            var.create_app2 ? "    HostName ${aws_instance.app2[0].private_ip}" : "",
            var.create_app2 ? "    User ubuntu" : "",
            var.create_app2 ? "    IdentityFile ~/.ssh/id_ed25519" : "",
            var.create_app2 ? "    StrictHostKeyChecking no" : "",
            var.create_app2 ? "    UserKnownHostsFile /dev/null" : "",
            "EOF",
            "chmod 600 /home/ubuntu/.ssh/config",
            "chown ubuntu:ubuntu /home/ubuntu/.ssh/config"
          ]
        }
      }
    ]
  })
  depends_on = [aws_iam_instance_profile.ec2_profile]
}

resource "aws_ssm_association" "deploy_ssh_config" {
  name = aws_ssm_document.ssh_config.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.bastion.id]
  }
  depends_on = [aws_ssm_association.deploy_private_to_bastion]
}
