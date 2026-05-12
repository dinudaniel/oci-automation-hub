# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

# =============================================================================
# Network Outputs
# =============================================================================
output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.this.id
}

output "subnet_id" {
  description = "OCID of the compute subnet."
  value       = oci_core_subnet.compute.id
}

output "nsg_id" {
  description = "OCID of the compute NSG."
  value       = oci_core_network_security_group.compute.id
}

# =============================================================================
# Compute Outputs
# =============================================================================
output "instance_ids" {
  description = "OCIDs of the deployed instances."
  value       = join(", ", oci_core_instance.this[*].id)
}

output "instance_private_ips" {
  description = "Private IP addresses of the instances."
  value       = join(", ", oci_core_instance.this[*].private_ip)
}

output "instance_public_ips" {
  description = "Public IP addresses of the instances (empty if private subnet)."
  value       = join(", ", compact([for i in oci_core_instance.this : i.public_ip]))
}

output "instance_details" {
  description = "Summary of deployed instances."
  value = [
    for i in oci_core_instance.this : {
      name       = i.display_name
      shape      = i.shape
      state      = i.state
      private_ip = i.private_ip
      public_ip  = i.public_ip
      ad         = i.availability_domain
    }
  ]
}

# =============================================================================
# Block Volume Outputs
# =============================================================================
output "block_volume_ids" {
  description = "OCIDs of the block volumes."
  value       = var.create_block_volumes ? join(", ", oci_core_volume.this[*].id) : "N/A"
}

output "block_volume_attachment_ids" {
  description = "OCIDs of the block volume attachments."
  value       = var.create_block_volumes ? join(", ", oci_core_volume_attachment.this[*].id) : "N/A"
}

# =============================================================================
# Connection Info
# =============================================================================
output "ssh_connection_commands" {
  description = "SSH connection commands for each instance."
  value = var.subnet_is_public && var.assign_public_ip ? [
    for i in oci_core_instance.this :
    "ssh opc@${i.public_ip}"
    if i.public_ip != null && i.public_ip != ""
  ] : ["Instances are on a private subnet. Use a bastion or VPN to connect."]
}

# =============================================================================
# Benchmark Outputs
# =============================================================================
output "benchmark_summary" {
  description = "Sysbench benchmark configuration and where to find results."
  value = var.run_benchmark && var.run_sysbench ? join("\n", [
    "=== Sysbench Benchmark (run_id: ${var.benchmark_run_id}) ===",
    "",
    "Configuration:",
    "  Instances:     ${var.instance_count}",
    "  Shape:         ${var.instance_shape}",
    "  OCPUs:         ${local.is_flex_shape ? var.instance_flex_ocpus : "fixed"}",
    "  Threads:       ${var.sysbench_threads == 0 ? "auto (all CPUs)" : var.sysbench_threads}",
    "  CPU Max Prime: ${var.sysbench_cpu_max_prime}",
    "  Duration:      ${var.sysbench_duration}s",
    "  Memory Test:   ${var.run_memory_benchmark ? "YES (block=${var.sysbench_memory_block_size}, total=${var.sysbench_memory_total_size})" : "NO"}",
    "",
    "Results Location:",
    "  • OCI Console → Observability & Management → Logging → Log Search",
    "  • Log Group: ${var.resource_name_prefix}-benchmark-logs",
    "  • Filter by: subject = 'benchmark-run-${var.benchmark_run_id}'",
    "  • Also in RM Apply Logs → search for 'FINAL RESULTS'",
    "",
    "To re-run: change Benchmark Run ID to '${tonumber(var.benchmark_run_id) + 1}' and Apply",
  ]) : "Sysbench: DISABLED"
}

output "benchmark_log_group_id" {
  description = "OCID of the benchmark Log Group."
  value       = var.run_benchmark ? oci_logging_log_group.benchmark[0].id : "N/A"
}

output "benchmark_log_id" {
  description = "OCID of the benchmark Custom Log."
  value       = var.run_benchmark ? oci_logging_log.benchmark[0].id : "N/A"
}

output "benchmark_log_search_url" {
  description = "Direct URL to search benchmark logs in OCI Console."
  value       = var.run_benchmark ? "https://cloud.oracle.com/logging/search?searchQuery=search%20%22${oci_logging_log_group.benchmark[0].id}%22&regions=${var.region}" : "N/A"
}

output "benchmark_results_commands" {
  description = "Commands to view benchmark results on each instance."
  value = var.run_benchmark && var.run_sysbench ? join("\n", [
    for i in oci_core_instance.this :
    "ssh opc@${i.public_ip != "" && i.public_ip != null ? i.public_ip : i.private_ip} 'cat /tmp/benchmark-results.txt'"
  ]) : "Sysbench is disabled."
}

# =============================================================================
# FIO Benchmark Outputs
# =============================================================================
output "fio_benchmark_summary" {
  description = "FIO benchmark configuration summary."
  value = var.run_benchmark && var.run_fio && var.create_block_volumes ? join("\n", [
    "=== FIO Storage Benchmark (run_id: ${var.benchmark_run_id}) ===",
    "",
    "Configuration:",
    "  Instances:       ${var.instance_count}",
    "  BV Size:         ${var.block_volume_size_in_gbs} GB",
    "  BV VPUs/GB:      ${var.block_volume_vpus_per_gb}",
    "  BV Attachment:   ${var.block_volume_attachment_type}",
    "  Test Pattern:    ${var.fio_test_pattern}",
    "  Block Size:      ${var.fio_block_size}",
    "  I/O Depth:       ${var.fio_io_depth}",
    "  Jobs:            ${var.fio_num_jobs == 0 ? "auto (all CPUs)" : var.fio_num_jobs}",
    "  Duration:        ${var.fio_duration}s",
    "  File Size:       ${var.fio_file_size}",
    "  Direct I/O:      ${var.fio_direct ? "yes" : "no"}",
    "  RW Mix Read:     ${var.fio_test_pattern == "randrw" ? "${var.fio_rwmixread}%" : "N/A"}",
    "",
    "Results Location:",
    "  • OCI Console → Observability & Management → Logging → Log Search",
    "  • Log Group: ${var.resource_name_prefix}-benchmark-logs",
    "  • Filter by: subject = 'benchmark-run-${var.benchmark_run_id}' AND type = 'com.oraclecloud.benchmark.fio'",
    "  • Also in RM Apply Logs → search for 'FIO RESULTS'",
  ]) : var.run_fio && !var.create_block_volumes ? "FIO: DISABLED (requires block volumes — set create_block_volumes = true)" : "FIO: DISABLED"
}

output "fio_log_id" {
  description = "OCID of the FIO Custom Log."
  value       = var.run_benchmark && var.run_fio ? oci_logging_log.fio[0].id : "N/A"
}

output "fio_results_commands" {
  description = "Commands to view FIO results on each instance."
  value = var.run_benchmark && var.run_fio && var.create_block_volumes ? join("\n", [
    for i in oci_core_instance.this :
    "ssh opc@${i.public_ip != "" && i.public_ip != null ? i.public_ip : i.private_ip} 'cat /tmp/fio-benchmark-results.txt'"
  ]) : "FIO benchmark is disabled."
}
