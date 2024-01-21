# Terraform AWS VPC module

This module manages the creation of a VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables, Security Group and their associated rules on AWS.

## Requirements

- Terraform version 1.7.0 or newer
- AWS provider version 5.0 or newer

## Providers

- AWS

## Resources

- `aws_vpc.main`: This resource creates a VPC.
- `aws_subnet.main`: This resource creates subnets within the VPC.
- `aws_internet_gateway.main`: This resource creates an internet gateway and attaches it to the VPC.
- `aws_eip.main`: This resource creates an Elastic IP for the NAT Gateway.
- `aws_nat_gateway.main`: This resource creates a NAT Gateway within the specified subnet.
- `aws_route_table.main`: This resource creates a route table within the VPC.
- `aws_route_table_association.main`: This resource associates subnets with the route table.
- `aws_security_group.main`: This resource creates a security group within the VPC.
- `aws_vpc_security_group_ingress_rule.main`: This resource creates ingress rules for the security group.
- `aws_vpc_security_group_egress_rule.main`: This resource creates egress rules for the security group.
- `aws_default_security_group.default`: This resource manages the default security group within the VPC.

## Inputs

- `vpc`: A map where each item represents a VPC.
- `subnets`: A map where each item represents a subnet.
- `internet_gateway`: A map where each item represents an internet gateway.
- `nat_gateway`: A map where each item represents a NAT gateway.
- `route_tables`: A map where each item represents a route table.
- `route_table_associations`: A map where each item represents a route table association.
- `security_groups`: A map where each item represents a security group.

## Outputs

- `vpc_ids`: The IDs of the created VPCs.
- `subnet_ids`: The IDs of the created subnets.
- `internet_gateway_ids`: The IDs of the created internet gateways.
- `nat_gateway_ids`: The IDs of the created NAT gateways.
- `route_table_ids`: The IDs of the created route tables.
- `security_group_ids`: The IDs of the created security groups.

## Example Usage
The module can be used in the following way:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.7.0"
}

provider "aws" {
  region = var.region
}

locals {
  vpc_config = {
    for vpc_name, vpc_info in var.vpc_config : vpc_name => {
      cidr_block           = vpc_info.cidr_block
      enable_dns           = coalesce(vpc_info.enable_dns, true)
      enable_dns_hostnames = coalesce(vpc_info.enable_dns_hostnames, false)
    }
  }

  sn_config = {
    for sn_name, sn_info in var.sn_config : sn_name => {
      vpc_name          = sn_info.vpc_name
      cidr_block        = sn_info.cidr_block
      availability_zone = sn_info.availability_zone
    }
  }

  igw_config = {
    for igw_name, igw_info in var.igw_config : igw_name => {
      vpc_name = igw_info.vpc_name
    }
  }

  ngw_config = {
    for ngw_name, ngw_info in var.ngw_config : ngw_name => {
      vpc_name    = ngw_info.vpc_name
      subnet_name = ngw_info.subnet_name
    }
  }

  rt_config = {
    for rt_name, rt_info in var.rt_config : rt_name => {
      vpc_name = rt_info.vpc_name
      routes = [
        for route_info in rt_info.routes : {
          cidr_block = route_info.cidr_block
          use_igw    = coalesce(route_info.use_igw, true)
          igw_name   = coalesce(route_info.igw_name, "default")
          use_ngw    = coalesce(route_info.use_ngw, false)
          ngw_name   = coalesce(route_info.ngw_name, "default")
        }
      ]
    }
  }

  rta_config = {
    for rta_name, rta_info in var.rta_config : rta_name => {
      subnet_name      = rta_info.subnet_name
      route_table_name = rta_info.route_table_name
    }
  }

  sg_config = {
    for sg_name, sg_info in var.sg_config : sg_name => {
      vpc_name = sg_info.vpc_name
      ingress = {
        for ingress_key, ingress_info in sg_info.ingress : ingress_key => {
          from_port           = ingress_info.from_port
          to_port             = ingress_info.to_port
          protocol            = ingress_info.protocol
          cidr_ipv4           = ingress_info.cidr_ipv4
          security_group_name = ingress_info.security_group_name
        }
      }
      egress = {
        for egress_key, egress_info in sg_info.egress : egress_key => {
          from_port           = egress_info.from_port
          to_port             = egress_info.to_port
          protocol            = egress_info.protocol
          cidr_ipv4           = egress_info.cidr_ipv4
          security_group_name = egress_info.security_group_name
        }
      }
    }
  }
}

module "vpc" {
  source = "src"

  ## VPC configuration
  vpc                      = local.vpc_config
  subnets                  = local.sn_config
  internet_gateway         = local.igw_config
  nat_gateway              = local.ngw_config
  route_tables             = local.rt_config
  route_table_associations = local.rta_config
  security_groups          = local.sg_config

}
```

The following example TFVars can be used with this module.

```hcl
vpc_config = {
  "dev1" = {
    cidr_block           = "10.0.0.0/16"
    enable_dns           = true
    enable_dns_hostnames = false
  }
}

## Subnet configuration
sn_config = {
  "public1-dev1" = {
    vpc_name          = "dev1"
    cidr_block        = "10.0.1.0/24"
    availability_zone = "eu-west-1a"
  },
  "public2-dev1" = {
    vpc_name          = "dev1"
    cidr_block        = "10.0.2.0/24"
    availability_zone = "eu-west-1b"
  }
  "private1-dev1" = {
    vpc_name          = "dev1"
    cidr_block        = "10.0.10.0/24"
    availability_zone = "eu-west-1a"
  },
  "private2-dev1" = {
    vpc_name          = "dev1"
    cidr_block        = "10.0.20.0/24"
    availability_zone = "eu-west-1b"
  }
  "reserve1-dev1" = {
    vpc_name          = "dev1"
    cidr_block        = "10.0.100.0/24"
    availability_zone = "eu-west-1a"
  },
  "reserve2-dev1" = {
    vpc_name          = "dev1"
    cidr_block        = "10.0.200.0/24"
    availability_zone = "eu-west-1b"
  }
}

## Internet Gateway configuration
igw_config = {
  "igw1-dev1" = {
    vpc_name = "dev1"
  }
}

## Nat Gateway configuration
ngw_config = {
  "ngw1-dev1" = {
    vpc_name    = "dev1"
    subnet_name = "public1-dev1"
  }
  "ngw2-dev1" = {
    vpc_name    = "dev1"
    subnet_name = "public2-dev1"
  }
}

## Route Table configuration
rt_config = {
  "rt1-dev1" = {
    vpc_name = "dev1"
    routes = [
      {
        cidr_block = "0.0.0.0/0"
        use_igw    = true
        igw_name   = "igw1-dev1"
        use_ngw    = false
      }
    ]
  },
  "rt2-dev1" = {
    vpc_name = "dev1"
    routes = [
      {
        cidr_block = "0.0.0.0/0"
        use_igw    = false
        use_ngw    = true
        ngw_name   = "ngw1-dev1"
      }
    ]
  },
}

## Route Table Association configuration      
rta_config = {
  "rta1-dev1" = {
    subnet_name      = "public1-dev1"
    route_table_name = "rt1-dev1"
  }
  "rta2-dev1" = {
    subnet_name      = "public2-dev1"
    route_table_name = "rt1-dev1"
  }
  "rta3-dev1" = {
    subnet_name      = "private1-dev1"
    route_table_name = "rt2-dev1"
  }
  "rta4-dev1" = {
    subnet_name      = "private2-dev1"
    route_table_name = "rt2-dev1"
  }
}

## Security Group configuration
sg_config = {
  "bastion-dev1" = {
    vpc_name = "dev1"
    ingress = {
      "ssh" = {
        from_port = 22
        to_port   = 22
        protocol  = "tcp"
        cidr_ipv4 = "0.0.0.0/0"
      }
    }
    egress = {
      "http" = {
        from_port = 80
        to_port   = 80
        protocol  = "tcp"
        cidr_ipv4 = "0.0.0.0/0"
      },
      "https" = {
        from_port = 443
        to_port   = 443
        protocol  = "tcp"
        cidr_ipv4 = "0.0.0.0/0"
      },
      "ssh" = {
        from_port           = 22
        to_port             = 22
        protocol            = "tcp"
        security_group_name = "private-dev1"
      },
    }
  }
  "private-dev1" = {
    vpc_name = "dev1"
    ingress = {
      "ssh" = {
        from_port           = 22
        to_port             = 22
        protocol            = "tcp"
        security_group_name = "bastion-dev1"
      }
    }
    egress = {
      "http" = {
        from_port = 80
        to_port   = 80
        protocol  = "tcp"
        cidr_ipv4 = "0.0.0.0/0"
      },
      "https" = {
        from_port = 443
        to_port   = 443
        protocol  = "tcp"
        cidr_ipv4 = "0.0.0.0/0"
      }
    }
  }
}
```