# Copyright (c) 2024, 2026, Oracle and/or its affiliates. All rights reserved.
# The Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl/

terraform {
  required_version = ">= 1.2.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

# When running in Resource Manager, authentication is handled automatically.
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}

# Home region provider — required for Identity resources (dynamic groups, policies)
provider "oci" {
  alias        = "home"
  tenancy_ocid = var.tenancy_ocid
  region       = local.home_region
}
