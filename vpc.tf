resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.environment}-${local.service}-vpc-${local.region}"
  }
}

resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, index(var.public_subnets, each.value))
  tags = {
    Name = "${local.environment}-${local.service}-public-${each.value}-${local.region}"
  }
}

resource "aws_subnet" "private" {
  for_each          = toset(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = element(data.aws_availability_zones.available.names, index(var.private_subnets, each.value))
  tags = {
    Name = "${local.environment}-${local.service}-private-${each.value}-${local.region}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.environment}-${local.service}-igw-${local.region}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.environment}-${local.service}-public-rt-${local.region}"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${local.environment}-${local.service}-nat-eip-${local.region}"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = element(values(aws_subnet.public), 0).id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name        = "${local.environment}-${local.service}-nat-gateway-${local.region}"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.environment}-${local.service}-private-rt-${local.region}"
  }
}

resource "aws_route" "private_to_nat" {
  count                  = var.create_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
