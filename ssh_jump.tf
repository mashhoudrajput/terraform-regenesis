resource "tls_private_key" "jump" {
  algorithm = "ED25519"
}

resource "aws_ssm_document" "write_private_key" {
  name          = "write-jump-private-key-${local.environment}"
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
            "cat > /home/ubuntu/.ssh/id_ed25519_jump <<'KEY'",
            tls_private_key.jump.private_key_pem,
            "KEY",
            "chmod 600 /home/ubuntu/.ssh/id_ed25519_jump",
            "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_ed25519_jump"
          ]
        }
      }
    ]
  })
  depends_on = [aws_iam_instance_profile.ec2_profile]
}

resource "aws_ssm_document" "append_public_key" {
  name          = "append-jump-public-key-${local.environment}"
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
    values = [aws_instance.app.id]
  }
}

output "jump_public_key" {
  value       = tls_private_key.jump.public_key_openssh
  description = "The public key that was deployed to the app's authorized_keys"
}
