# Ori Homework (DevOps)

## Overview
* Fully automated (de-)provisioning via `terraform`
* Script injection via Azure's Virtual Machine Extensions
* Manual validation/interaction with VM via RDP

## Scripts
* PS Script Module - `scripts/Ori.LocalServerCmdlets.psm1`
* PS ExampleScript - `scripts/ExampleScript.ps1`

## Prerequisites (Common)
* Download `terraform` - https://www.terraform.io/downloads.html
* Place `terraform(.exe)` binary somewhere in `PATH`
* Get a service principal with appropriate permissions from Azure CLI (create `app`, `sp`, assign `role` `Contributor`)

## For Linux
```bash
export TF_VAR_azure_subscription_id="XXX"
export TF_VAR_azure_client_id="XXX"
export TF_VAR_azure_client_secret="XXX"
export TF_VAR_azure_tenant_id="XXX"
export TF_VAR_azure_vm_admin_password="XXX"

terraform init
terraform plan -out my_ori_plan
terraform apply my_ori_plan

# Run RDP client here and enter provided credentials
# e.g., xfreerdp --ignore-certificate --sec nla -u 'ori-hw-vm1' --from-stdin $IP_ADDRESS
```

## For Windows
```PowerShell
$env:TF_VAR_azure_subscription_id="XXX"
$env:TF_VAR_azure_client_id="XXX"
$env:TF_VAR_azure_client_secret="XXX"
$env:TF_VAR_azure_tenant_id="XXX"
$env:TF_VAR_azure_vm_admin_password="XXX"

terraform.exe init
terraform.exe plan -out my_ori_plan
terraform.exe apply my_ori_plan

# Run your RDP client here with the given IP address and provided credentials
```

## Inside VM (Common)
```PowerShell
# Extension installed scripts here
cd C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Downloads\0

# No "*admin*" users
.\ExampleScript.ps1

# One "*admin*" user
New-LocalUser -Name MyAdmin1 -NoPassword
.\ExampleScript.ps1

# Two "*admin*" users, warning!
New-LocalUser -Name MyAdmin2 -NoPassword
.\ExampleScript.ps1
```

## Clean-up (Common)
```bash
terraform destroy
```
or
```PowerShell
terraform.exe destroy
```
