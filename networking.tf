locals {
  azs = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {}

resource "random_id" "random" {
  byte_length = 2
}

resource "aws_vpc" "sre_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "sre_vpc-${random_id.random.id}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "sre_internet_gateway" {
  vpc_id = aws_vpc.sre_vpc.id

  tags = {
    Name = "sre_igw"
  }
}

resource "aws_route_table" "sre_public_rt" {
  vpc_id = aws_vpc.sre_vpc.id

  tags = {
    Name = "sre-public"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.sre_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sre_internet_gateway.id
}

resource "aws_default_route_table" "sre_private_rt" {
  default_route_table_id = aws_vpc.sre_vpc.default_route_table_id

  tags = {
    Name = "sre_private"
  }
}

resource "aws_subnet" "sre_public_subnet" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.sre_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = local.azs[count.index]

  tags = {
    Name = "sre_public_${count.index + 1}"
  }
}

resource "aws_subnet" "sre_private_subnet" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.sre_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + length(local.azs))
  map_public_ip_on_launch = false
  availability_zone       = local.azs[count.index]

  tags = {
    Name = "sre_private_${count.index + 1}"
  }
}

resource "aws_route_table_association" "sre_public_assoc" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.sre_public_subnet.*.id[count.index]
  route_table_id = aws_route_table.sre_public_rt.id
}

resource "aws_security_group" "sre_sg" {
  name        = "public_sg"
  description = "Security group for public instances"
  vpc_id      = aws_vpc.sre_vpc.id
}

resource "aws_security_group_rule" "ingress_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [var.access_ip, var.cloud9_ip]
  security_group_id = aws_security_group.sre_sg.id
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sre_sg.id
}

resource "aws_db_subnet_group" "sre_db_subnet_group" {
  name       = "sre_db"
  subnet_ids = aws_subnet.sre_private_subnet.*.id

  tags = {
    Name = "sre_db_subnet_group"
  }
}

resource "aws_security_group" "sre_db_security_group" {
  name   = "sre_db_security_group"
  vpc_id = aws_vpc.sre_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sre_db_security_group"
  }
}
