# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

# =============================================================================
# OCI Logging — Benchmark Results
#
# Log Group and Custom Log are always created when benchmarking is enabled.
# Dynamic Group and IAM Policy are optional — set create_dynamic_group and
# create_policy to false if you already have the required IAM in place.
# =============================================================================

# -----------------------------------------------------------------------------
# Dynamic Group — optional (may already exist in the tenancy)
# -----------------------------------------------------------------------------
resource "oci_identity_dynamic_group" "benchmark_instances" {
  count    = var.create_dynamic_group ? 1 : 0
  provider = oci.home

  compartment_id = var.tenancy_ocid
  name           = "${var.resource_name_prefix}-benchmark-dg"
  description    = "Instances deployed by ${var.resource_name_prefix} stack for benchmark logging"

  matching_rule = "All {instance.compartment.id = '${var.compartment_ocid}'}"

  freeform_tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# IAM Policy — optional (may already exist in the tenancy)
# -----------------------------------------------------------------------------
resource "oci_identity_policy" "benchmark_logging" {
  count    = var.create_policy ? 1 : 0
  provider = oci.home

  compartment_id = var.compartment_ocid
  name           = "${var.resource_name_prefix}-benchmark-log-policy"
  description    = "Allow benchmark instances to push logs to OCI Logging"

  statements = [
    "Allow dynamic-group ${var.create_dynamic_group ? oci_identity_dynamic_group.benchmark_instances[0].name : "${var.resource_name_prefix}-benchmark-dg"} to use log-content in compartment id ${var.compartment_ocid}",
  ]

  freeform_tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Log Group
# -----------------------------------------------------------------------------
resource "oci_logging_log_group" "benchmark" {
  count = var.run_benchmark ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "${var.resource_name_prefix}-benchmark-logs"
  description    = "Benchmark results from sysbench runs on ${var.resource_name_prefix} instances"
  freeform_tags  = local.common_tags
}

# -----------------------------------------------------------------------------
# Custom Log — Sysbench
# -----------------------------------------------------------------------------
resource "oci_logging_log" "benchmark" {
  count = var.run_benchmark ? 1 : 0

  display_name = "${var.resource_name_prefix}-sysbench-results"
  log_group_id = oci_logging_log_group.benchmark[0].id
  log_type     = "CUSTOM"
  is_enabled   = true

  retention_duration = 30

  freeform_tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Custom Log — FIO
# -----------------------------------------------------------------------------
resource "oci_logging_log" "fio" {
  count = var.run_benchmark && var.run_fio ? 1 : 0

  display_name = "${var.resource_name_prefix}-fio-results"
  log_group_id = oci_logging_log_group.benchmark[0].id
  log_type     = "CUSTOM"
  is_enabled   = true

  retention_duration = 30

  freeform_tags = local.common_tags
}
