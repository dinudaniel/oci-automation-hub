# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

# =============================================================================
# VCN
# =============================================================================
resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr_block]
  display_name   = "${var.resource_name_prefix}-vcn"
  dns_label      = var.vcn_dns_label
  freeform_tags  = local.common_tags
}

# =============================================================================
# Internet Gateway (for public subnets)
# =============================================================================
resource "oci_core_internet_gateway" "this" {
  count = var.subnet_is_public ? 1 : 0

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.resource_name_prefix}-igw"
  enabled        = true
  freeform_tags  = local.common_tags
}

# =============================================================================
# NAT Gateway (for private subnets)
# =============================================================================
resource "oci_core_nat_gateway" "this" {
  count = var.subnet_is_public ? 0 : 1

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.resource_name_prefix}-natgw"
  freeform_tags  = local.common_tags
}

# =============================================================================
# Service Gateway (for OCI services access from private subnets)
# =============================================================================
data "oci_core_services" "all" {}

resource "oci_core_service_gateway" "this" {
  count = var.subnet_is_public ? 0 : 1

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.resource_name_prefix}-sgw"

  services {
    service_id = data.oci_core_services.all.services[index(
      data.oci_core_services.all.services[*].name,
      "All ${var.region} Services In Oracle Services Network"
    )].id
  }

  freeform_tags = local.common_tags
}

# =============================================================================
# Route Tables
# =============================================================================
resource "oci_core_route_table" "public" {
  count = var.subnet_is_public ? 1 : 0

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.resource_name_prefix}-rt-public"
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this[0].id
    description       = "Default route via Internet Gateway"
  }
}

resource "oci_core_route_table" "private" {
  count = var.subnet_is_public ? 0 : 1

  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.resource_name_prefix}-rt-private"
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this[0].id
    description       = "Default route via NAT Gateway"
  }
}

# =============================================================================
# Default Security List — minimal (NSG handles the real rules)
# =============================================================================
resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "${var.resource_name_prefix}-default-sl"
  freeform_tags              = local.common_tags

  # Allow all egress
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
    description = "Allow all outbound traffic"
  }

  # ICMP for path discovery
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = var.vcn_cidr_block
    stateless   = false
    description = "ICMP within VCN"

    icmp_options {
      type = 3
      code = 4
    }
  }
}

# =============================================================================
# Subnet
# =============================================================================
resource "oci_core_subnet" "compute" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.subnet_cidr_block
  display_name               = "${var.resource_name_prefix}-subnet-compute"
  dns_label                  = var.subnet_dns_label
  prohibit_internet_ingress  = var.subnet_is_public ? false : true
  prohibit_public_ip_on_vnic = var.subnet_is_public ? false : true
  route_table_id             = var.subnet_is_public ? oci_core_route_table.public[0].id : oci_core_route_table.private[0].id
  freeform_tags              = local.common_tags
}

# =============================================================================
# Network Security Group + Rules
# =============================================================================
resource "oci_core_network_security_group" "compute" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.resource_name_prefix}-nsg-compute"
  freeform_tags  = local.common_tags
}

# Egress — allow all outbound
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.compute.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all egress"
}

# Ingress — dynamic rules based on selected preset
resource "oci_core_network_security_group_security_rule" "ingress" {
  for_each = {
    for idx, rule in local.selected_nsg_rules : idx => rule
  }

  network_security_group_id = oci_core_network_security_group.compute.id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  source                    = each.value.source
  source_type               = each.value.source_type
  description               = each.value.description

  dynamic "tcp_options" {
    for_each = each.value.tcp_port != null ? [1] : []
    content {
      destination_port_range {
        min = each.value.tcp_port
        max = each.value.tcp_port
      }
    }
  }
}
