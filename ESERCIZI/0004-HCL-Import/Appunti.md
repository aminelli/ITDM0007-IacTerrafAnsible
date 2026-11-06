# Codice Import


```powershell
# Componenti az utili
winget install Microsoft.Azure.AztfExport
az extension add --name resource-graph


# Comando base per importare in script terraform un gruppo di risorse e i suoi servizi
# modalità non interattiva
aztfexport rg `
    --provider-name azurerm `
    --non-interactive `
    --generate-mapping-file `
    rg-demo-dev

# modalità interattiva
aztfexport rg `
    --provider-name azurerm `
    rg-demo-dev



# Comando aggiuntivo per importare in script terraform i servizi non coperti dal provider "azurerm"
aztfexport rg `
    --provider-name azapi `
    rg-demo-dev

############################### 
# IMPORT MANUEALE CON TERRAFORM

az login
az account set --subscription "00000000-0000-0000-0000-000000000000"
terraform version   # >= 1.7 consigliato

$rg = "rg-demo-dev"
az resource list -g $rg --query "[].{type:type, name:name}" -o table
az resource list -g $rg -o table

###########################
### Import2: comando terraform per generare il codice tf
terraform plan -generate-config-out="generated.tf"

```