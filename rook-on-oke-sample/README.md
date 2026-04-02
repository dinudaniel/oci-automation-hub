# Rook on OKE

This repository provides the necessary Terraform configuration to deploy Rook on a fresh Oracle Kubernetes Engine (OKE) cluster. Rook is a suite of advanced workload controllers that extends Kubernetes with powerful features for application management, deployment, and operations.

## How It Works

The repository is structured as a Terraform project that deploys an OKE cluster with attached block volumes for Rook OSDs.

-   **`main.tf`**: Main Terraform file that sets up the OKE cluster using the OKE module.
-   **`bv.tf`**: Creates and attaches block volumes to worker nodes for Rook OSD storage.
-   **`variables.tf`**: Defines the input variables for the Terraform configuration.
-   **`provider.tf`**: Configures the OCI and Kubernetes providers for Terraform.
-   **`schema.yaml`**: OCI Resource Manager schema for guided deployment.
-   **`rook-files/`**: Contains example YAML files for the top 3 most common use cases.

This project can be deployed in two ways:
1.  **Automated Deployment**: Using OCI Resource Manager.
2.  **Manual Deployment**: Using Terraform CLI on your local machine.

## Task 1: Create necessary resources

### Option A: Automated Deployment (OCI Resource Manager)

> **Note:** The following steps show how to deploy an OKE cluster with Rook storage using OCI Resource Manager

1. Clone the terraform files from github.

2. Use Oracle Resource Manager to create and apply the stack

    - using the hamburger menu, go to Oracle Resource Manager
    - choose `Stacks`
    - click `Create stack`
    - select `My configuration` radio button
    - in `My configuration` section make sure `Folder` is selected; choose the folder where you previously cloned the git repo; click `Upload`
    - give the stack a meaningful name
    - click `Next`
    - choose the compartment where the resources will be created
    - choose the ssh public key that will be used to connect to bastion and operator hosts
    - adjust the cluster name, Kubernetes version, and node pool size as needed
    - if the IAM resources (dynamic groups and policies) do not already exist, enable the `Create IAM resources` option at the bottom
    - click `Next`
    - on the next screen select `Run apply` check-box
    - click `Create`

3. Connect to the operator host

    - upon successful run of the job from previous step, go to the stack `Outputs` section
    - copy the `ssh_to_operator` command and run it in your terminal to connect to the operator host via the bastion:
      ```sh
      ssh -o ProxyCommand='ssh -W %h:%p -i <key> opc@<bastion_ip>' -i <key> opc@<operator_ip>
      ```
    - from the operator host you can run `kubectl` commands against the OKE cluster

### Option B: Manual Deployment (Terraform CLI)

#### Prerequisites

*   OCI tenancy
*   Your OCI user OCID, tenancy OCID, fingerprint, and private key.
*   The region where your OKE cluster will be located.
*   Terraform CLI installed on your local machine.

#### Steps

1.  Clone the repository:
    ```sh
    git clone https://github.com/oracle-devrel/oci-automation-hub.git
    cd oci-automation-hub/rook-on-oke-sample
    ```

2.  Create a `terraform.auto.tfvars` file and add the following variables:
    ```tfvars
    tenancy_ocid      = "ocid1.tenancy.oc1..your_tenancy_ocid"
    current_user_ocid = "ocid1.user.oc1..your_user_ocid"
    compartment_ocid  = "ocid1.compartment.oc1..your_compartment_ocid"
    # fingerprint      = "your_api_key_fingerprint"
    # private_key_path = "/path/to/your/oci_api_key.pem"
    region            = "your-oci-region"
    ssh_public_key    = "ssh-rsa AAAA..."
    ```

3.  Initialize and apply:
    ```sh
    terraform init
    terraform plan
    terraform apply
    ```

4.  Connect to the operator host using the `ssh_to_operator` output:
    ```sh
    terraform output ssh_to_operator
    ```

## Post-Installation

Once Rook is deployed, you can verify the installation by checking the pods in the `rook-ceph` namespace:

```sh
kubectl get pods -n rook-ceph
```

You can now start using Rook's advanced workloads and features. For more information on how to use Rook, refer to the [official Rook documentation](https://rook.io/docs/).

## Task 2: Clean-up

### Option A: OCI Resource Manager

1. Destroy the resources created using the terraform stack

    - navigate back to Oracle Resource Manager
    - select the stack you created
    - click `Destroy`

### Option B: Terraform CLI

1. Destroy the resources:
    ```sh
    terraform destroy
    ```
