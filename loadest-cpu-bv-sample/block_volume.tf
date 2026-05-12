# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

# =============================================================================
# Block Volumes — one per compute instance
#
# Created and attached only when create_block_volumes = true.
# Required for FIO storage benchmarks.
# =============================================================================

# -----------------------------------------------------------------------------
# Block Volumes
# -----------------------------------------------------------------------------
resource "oci_core_volume" "this" {
  count = var.create_block_volumes ? var.instance_count : 0

  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[count.index % length(data.oci_identity_availability_domains.this.availability_domains)].name
  display_name        = "${var.resource_name_prefix}-bv-${count.index + 1}"
  size_in_gbs         = var.block_volume_size_in_gbs
  vpus_per_gb         = var.block_volume_vpus_per_gb

  freeform_tags = merge(local.common_tags, { "InstanceIndex" = tostring(count.index + 1) })
}

# -----------------------------------------------------------------------------
# Volume Attachments — attach each BV to its corresponding compute instance
# -----------------------------------------------------------------------------
resource "oci_core_volume_attachment" "this" {
  count = var.create_block_volumes ? var.instance_count : 0

  attachment_type = var.block_volume_attachment_type
  instance_id     = oci_core_instance.this[count.index].id
  volume_id       = oci_core_volume.this[count.index].id
  display_name    = "${var.resource_name_prefix}-bv-attach-${count.index + 1}"

  # For paravirtualized, the device path is auto-assigned
  # For iSCSI, the instance needs to run iscsiadm commands (handled in fio_benchmark.tf)
  is_read_only = false
  is_shareable = false
}
