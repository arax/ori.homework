# Ori Homework (DevOps)

## Common
* Download `terraform` - https://www.terraform.io/downloads.html
* Place `terraform` binary somewhere in `PATH`
* Get a service principal with appropriate permissions from Azure CLI (create `app`, `sp`, assign `role`)

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

xfreerdp --ignore-certificate --sec nla -u 'ori-hw-vm1' --from-stdin IP_ADDRESS
```

## For Windows
```PowerShell
$env:TF_VAR_azure_subscription_id="XXX"
$env:TF_VAR_azure_client_id="XXX"
$env:TF_VAR_azure_client_secret="XXX"
$env:TF_VAR_azure_tenant_id="XXX"
$env:TF_VAR_azure_vm_admin_password="XXX"

terraform init
terraform plan -out my_ori_plan
terraform apply my_ori_plan

# Run your RDP client here with the given IP address and password
```
