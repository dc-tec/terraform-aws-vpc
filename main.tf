terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.7.0"
}

data "aws_region" "current" {}

resource "aws_vpc" "main" {
  for_each = var.vpc

  cidr_block           = each.value.cidr_block
  enable_dns_support   = each.value.enable_dns
  enable_dns_hostnames = each.value.enable_dns_hostnames

  tags = merge(
    var.tags,
    {
      "Name" = "vpc-${each.key}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_subnet" "main" {
  for_each = {
    for key, value in var.subnets : key => value
  }

  vpc_id            = aws_vpc.main[each.value.vpc_name].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(
    var.tags,
    {
      "Name" = "sn-${each.key}-${each.value.availability_zone}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_internet_gateway" "main" {
  for_each = var.internet_gateway

  vpc_id = aws_vpc.main[each.value.vpc_name].id

  tags = merge(
    var.tags,
    {
      "Name" = "igw-${each.key}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_eip" "main" {
  for_each = var.nat_gateway

  domain = "vpc"
  tags = merge(
    var.tags,
    {
      "Name" = "eip-${each.key}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_nat_gateway" "main" {
  depends_on = [aws_internet_gateway.main]
  for_each   = var.nat_gateway

  allocation_id = aws_eip.main[each.key].id
  subnet_id     = aws_subnet.main[each.value.subnet_name].id

  tags = merge(
    var.tags,
    {
      "Name" = "ngw-${each.key}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_route_table" "main" {
  for_each = var.route_tables

  vpc_id = aws_vpc.main[each.value.vpc_name].id

  dynamic "route" {
    for_each = each.value.routes

    content {
      cidr_block     = route.value.cidr_block
      gateway_id     = route.value.use_igw ? aws_internet_gateway.main[route.value.igw_name].id : null
      nat_gateway_id = route.value.use_ngw ? aws_nat_gateway.main[route.value.ngw_name].id : null
      # network_interface_id      = route.value.use_ec2ni ? aws_network_interface.ec2ni[each.key].id : route.value.network_interface_id
      # vpc_peering_connection_id = route.value.use_vpcpc ? aws_vpc_peering_connection.vpcpc[each.key].id : route.value.vpc_peering_connection_id
      # vpc_endpoint_id           = route.value.use_vpce ? aws_vpc_endpoint.vpce[each.key].id : route.value.vpc_endpoint_id
    }
  }

  tags = merge(
    var.tags,
    {
      "Name" = "rt-${each.key}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_route_table_association" "main" {
  for_each = var.route_table_associations

  subnet_id      = aws_subnet.main[each.value.subnet_name].id
  route_table_id = aws_route_table.main[each.value.route_table_name].id
}

resource "aws_security_group" "main" {
  for_each = var.security_groups

  description = "Security group for ${each.value.vpc_name} VPC"

  vpc_id = aws_vpc.main[each.value.vpc_name].id

  tags = merge(
    var.tags,
    {
      "Name" = "sg-${each.key}-${data.aws_region.current.name}"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "main" {
  for_each = {
    for sg in flatten([
      for sg_name, sg_config in var.security_groups :
      [for rule_name, rule_config in sg_config.ingress :
        {
          sg_name     = sg_name
          rule_name   = rule_name
          rule_config = rule_config
      }]
    ]) : "${sg.sg_name}.${sg.rule_name}" => sg
  }

  security_group_id = aws_security_group.main[each.value.sg_name].id

  cidr_ipv4                    = try(each.value.rule_config.cidr_ipv4, null)
  from_port                    = each.value.rule_config.from_port
  to_port                      = each.value.rule_config.to_port
  ip_protocol                  = each.value.rule_config.protocol
  referenced_security_group_id = try(aws_security_group.main[each.value.rule_config.security_group_name].id, null)
}

resource "aws_vpc_security_group_egress_rule" "main" {
  for_each = {
    for sg in flatten([
      for sg_name, sg_config in var.security_groups :
      [for rule_name, rule_config in sg_config.egress :
        {
          sg_name     = sg_name
          rule_name   = rule_name
          rule_config = rule_config
      }]
    ]) : "${sg.sg_name}.${sg.rule_name}" => sg
  }

  security_group_id = aws_security_group.main[each.value.sg_name].id

  cidr_ipv4                    = try(each.value.rule_config.cidr_ipv4, null)
  from_port                    = each.value.rule_config.from_port
  to_port                      = each.value.rule_config.to_port
  ip_protocol                  = each.value.rule_config.protocol
  referenced_security_group_id = try(aws_security_group.main[each.value.rule_config.security_group_name].id, null)

}

resource "aws_default_security_group" "default" {
  for_each = var.vpc

  vpc_id = aws_vpc.main[each.key].id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}