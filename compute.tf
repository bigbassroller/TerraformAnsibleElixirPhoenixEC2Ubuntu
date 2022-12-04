locals {
  ansible_vars = templatefile("./ansible-vars.json.tpl", {
    db_user           = "${var.db_user}"
    db_password       = "${var.db_password}"
    db_name           = "${var.db_name}"
    main_domain_name  = "${var.main_domain_name}"
    db_host           = aws_db_instance.srw_db.endpoint
    github_token      = "${var.github_token}"
    github_user       = "${var.github_user}"
    github_repo       = "${var.github_repo}"
    letsencrypt_email = "${var.letsencrypt_email}"
  })
}

data "aws_ami" "server_ami" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "random_id" "srw_node_id" {
  byte_length = 2
  count       = var.main_instance_count
}

resource "aws_key_pair" "srw_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# RDS DB
resource "aws_db_parameter_group" "srw_db_parameter_group" {
  name   = "srw-db-parameter-group"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

resource "aws_db_instance" "srw_db" {
  identifier             = "srw-db"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "mysql"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.srw_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.srw_db_security_group.id]
  parameter_group_name   = aws_db_parameter_group.srw_db_parameter_group.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

# EC2
resource "aws_instance" "srw_main" {
  count                  = var.main_instance_count
  instance_type          = var.main_instance_type
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.srw_auth.id
  vpc_security_group_ids = [aws_security_group.srw_sg.id]
  subnet_id              = aws_subnet.srw_public_subnet[count.index].id

  root_block_device {
    volume_size = var.main_vol_size
  }
  
  tags = {
    Name = "srw-main-${random_id.srw_node_id[count.index].dec}"
  }

  # provisioner "local-exec" {
  #   command = "printf '\n${self.public_ip}' >> aws_hosts && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region ${var.region}"
  # }

  provisioner "local-exec" {
    command = "printf '\nubuntu@${data.aws_eip.srw_eip.public_ip}' >> hosts.txt && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region ${var.region}"
  }

  # provisioner "local-exec" {
  #   when    = destroy
  #   command = "sed -i '/^[0-9]/d' aws_hosts && sed -i '/^[a-z0-9@]/d' hosts.txt"
  # }

  provisioner "local-exec" {
    when    = destroy
    command = "sed -i '/^[a-z0-9@]/d' hosts.txt"
  }

  depends_on = [aws_db_instance.srw_db]

}

resource "null_resource" "ssh" {
  provisioner "remote-exec" {
    inline = ["touch upgrade.log && echo 'I sshd in' >> upgrade.log"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      # private_key = file("/home/ubuntu/.ssh/devops_rsa")
      private_key = file(var.private_key_path)
      host        = data.aws_eip.srw_eip.public_ip
    }
  }

  depends_on = [aws_eip_association.srw_eip_assoc]
}

# resource "null_resource" "main_playbook" {
#   provisioner "local-exec" {
#     command = "export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i hosts.txt --key-file /home/ubuntu/.ssh/devops_rsa playbooks/main-playbook.yml  --extra-vars '${local.ansible_vars}"
#   }
#   triggers = {
#     always_run = timestamp()
#   }
#   depends_on = [null_resource.ssh]
# }

resource "null_resource" "secure_server" {
  
  provisioner "local-exec" {
    command = "export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i hosts.txt --key-file /home/ubuntu/.ssh/devops_rsa playbooks/secure_server.yml"
  }

  depends_on = [null_resource.ssh]
}

resource "null_resource" "install_nginx" {
  depends_on = [null_resource.secure_server]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts.txt --key-file /home/ubuntu/.ssh/devops_rsa playbooks/install_nginx.yml"
  }
}

resource "null_resource" "install_php" {
  depends_on = [null_resource.install_nginx]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts.txt --key-file /home/ubuntu/.ssh/devops_rsa playbooks/install_php.yml"
  }
}

resource "null_resource" "provision_ssl_certificates" {
  depends_on = [null_resource.install_php]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts.txt --key-file /home/ubuntu/.ssh/devops_rsa playbooks/provision_ssl_certificates.yml --extra-vars '${local.ansible_vars}'"
  }
}

resource "null_resource" "install_wordpress" {
  depends_on = [null_resource.provision_ssl_certificates]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts.txt --key-file /home/ubuntu/.ssh/devops_rsa playbooks/install_wordpress.yml --extra-vars '${local.ansible_vars}'"
  }
}

data "aws_eip" "srw_eip" {
  id = var.allocation_id
}

resource "aws_eip_association" "srw_eip_assoc" {
  count         = var.main_instance_count
  instance_id   = aws_instance.srw_main[count.index].id
  allocation_id = data.aws_eip.srw_eip.id
}

output "IP" {
  value = data.aws_eip.srw_eip.public_ip
}

output "RDS-Endpoint" {
  value = aws_db_instance.srw_db.endpoint
}

output "instance_ips" {
  value = { for i in aws_instance.srw_main[*] : i.tags.Name => "${i.public_ip}:3000" }
}
