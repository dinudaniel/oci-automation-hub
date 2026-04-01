# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

locals {
  # Give the volumes a stable, searchable tag so we can find them if needed
  rook_bv_freeform_tags = {
    "managed-by" = "rook-on-oke"
    "purpose"    = "rook-osd"
  }

  # Per-node device map we want to attach: name, size, vpus, and the device path we expect on the host
  osd_disks = [
    { key = "data1", size_gb = 350, vpus_per_gb = 10,  device = "/dev/oracleoci/oraclevdb", label = "export"       },
    { key = "data2", size_gb = 700, vpus_per_gb = 120, device = "/dev/oracleoci/oraclevdc", label = "export-data"  },
  ]
}

# Read the node pool so we can get the instances (worker nodes) it created
data "oci_containerengine_node_pool" "np" {
  node_pool_id = module.oke.worker_pool_ids["simple-np"]
}

# Build a list of nodes ordered by index for stable referencing
locals {
  node_list = data.oci_containerengine_node_pool.np.nodes

  # Static keys based on node index and disk key — known at plan time
  volume_map = {
    for pair in flatten([
      for idx in range(var.simple_np_size) : [
        for disk in local.osd_disks : {
          key         = "${idx}:${disk.key}"
          node_idx    = idx
          size_gb     = disk.size_gb
          vpus_per_gb = disk.vpus_per_gb
        }
      ]
    ]) : pair.key => pair
  }

  attachment_map = {
    for pair in flatten([
      for idx in range(var.simple_np_size) : [
        for disk in local.osd_disks : {
          key      = "${idx}:${disk.key}"
          node_idx = idx
          device   = disk.device
        }
      ]
    ]) : pair.key => pair
  }
}

# Create the two volumes per instance
resource "oci_core_volume" "rook_osd" {
  for_each = local.volume_map

  compartment_id      = var.compartment_ocid
  availability_domain = local.node_list[each.value.node_idx].availability_domain
  display_name        = "rook-osd-${each.key}"
  size_in_gbs         = each.value.size_gb
  vpus_per_gb         = each.value.vpus_per_gb

  freeform_tags = merge(local.rook_bv_freeform_tags, {
    "node-instance-id" = local.node_list[each.value.node_idx].id
  })
}

# Attach the volumes to the corresponding node instance at fixed device paths
resource "oci_core_volume_attachment" "rook_osd_attach" {
  for_each = local.attachment_map

  attachment_type = "paravirtualized"
  instance_id     = local.node_list[each.value.node_idx].id
  volume_id       = oci_core_volume.rook_osd[each.key].id
  device          = each.value.device

  depends_on = [oci_core_volume.rook_osd]
}
