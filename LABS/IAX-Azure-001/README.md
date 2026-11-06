# VM Azure con Ubuntu, Java 21 e Tomcat 10

Progetto Terraform per distribuire una singola VM Linux in `northeurope`, con Ubuntu 26.04 LTS, Java 21, Tomcat 10, un IP pubblico e regole NSG per SSH e Tomcat.

## Architettura e scelte

Terraform crea un Resource Group, una VNet `10.0.0.0/16`, una subnet `10.0.1.0/24`, un NSG, un IP pubblico Standard statico, una NIC e una VM Linux. L'OS disk è gestito e usa `Standard_LRS` per default.

La VM usa `Standard_B2s` (2 vCPU, 4 GiB RAM), una SKU burstable: la CPU sostenibile dipende dai crediti accumulati. Una query Azure CLI in `northeurope` ha restituito la SKU senza restrizioni regionali. La quota effettiva dipende dalla subscription e va comunque verificata prima del deployment.

L'immagine configurata è `Canonical:ubuntu-26_04-lts:server:latest`. L'offerta e lo SKU identificano la release LTS; `latest` seleziona l'ultima build di quell'immagine, non passa automaticamente a una nuova release LTS. Al momento della generazione, il comando `az vm image show` in `northeurope` ha risolto `latest` alla build `26.04.202610280`. La versione esatta cambierà con le pubblicazioni Canonical.

Cloud-init installa `openjdk-21-jdk-headless` e `tomcat10`, imposta `JAVA_HOME` per il servizio `tomcat10`, verifica il connettore Tomcat sulla porta 8080 e abilita il servizio all'avvio. I pacchetti sono disponibili nei repository Ubuntu 26.04 `universe`; l'installazione dipende dalla raggiungibilità dei repository durante il bootstrap.

## Risorse Azure

| Risorsa | Funzione e configurazione |
|---|---|
| Resource Group | Contenitore logico per le risorse; nome e regione sono variabili. |
| Virtual Network e subnet | Rete isolata con spazio indirizzi e prefissi configurabili. |
| Network Security Group | Consente TCP/22 e TCP/8080 dai rispettivi CIDR configurati, quindi nega esplicitamente ogni altro traffico inbound. Il traffico outbound usa le regole predefinite NSG di Azure. |
| Public IP | IPv4 Standard, statico e associato alla NIC. |
| Network Interface | Interfaccia primaria della VM, collegata alla subnet, all'IP pubblico e all'NSG. |
| Linux Virtual Machine | Ubuntu 26.04 LTS, `Standard_B2s`, username/password, bootstrap cloud-init e tag comuni. |
| OS disk | Managed disk con tier configurabile (`Standard_LRS` o `Premium_LRS`). |

## Flussi di rete e sicurezza

- La porta TCP 22 è consentita dal CIDR configurato in `ssh_source_cidr`. Per scelta esplicita, il file di esempio usa `0.0.0.0/0`: ciò espone l'autenticazione SSH con password a tentativi da tutta Internet. È fortemente consigliato sostituirlo con una rete fidata, ad esempio un IP pubblico `/32`.
- La porta TCP 8080 è consentita dal CIDR configurato in `tomcat_source_cidr`. Il valore di esempio è `0.0.0.0/0`, quindi Tomcat è raggiungibile pubblicamente.
- Il traffico verso Tomcat usa HTTP, senza TLS. Non è configurata la porta 443 né un firewall Linux; l'NSG Azure e un eventuale firewall guest sono livelli distinti.
- Il provider riceve la password da `TF_VAR_admin_password`. La variabile Terraform è marcata `sensitive`, ma la password rimane memorizzata nello state e nei file di piano. Proteggere e limitare l'accesso a entrambi; non versionarli e non condividerli. Per ambienti condivisi, usare un backend remoto Azure Storage adeguatamente protetto con RBAC ristretto, cifratura e controlli di rete.
- La configurazione non contiene chiavi private né password in chiaro nei file versionati.

## File

- `versions.tf`: vincoli Terraform/provider e provider AzureRM.
- `variables.tf`: configurazione e validazioni.
- `main.tf`: rete, NSG, IP pubblico, NIC e VM.
- `outputs.tf`: nome, ID, IP e URL HTTP Tomcat.
- `cloud-init.yaml`: installazione e avvio dei pacchetti.
- `terraform.tfvars.example`: esempio di parametri non segreti.
- `.gitignore`: esclusione di state, file variabili locali, piani e directory del provider.

## Prerequisiti

- Terraform `>= 1.5.0` e `< 2.0.0`.
- Azure CLI autenticata e una subscription selezionata.
- Quota e disponibilità della SKU nella regione scelta.
- Accesso in uscita dalla VM ai repository Ubuntu per l'installazione dei pacchetti.

Autenticarsi e impostare la subscription per il provider AzureRM 4.x (PowerShell):

```powershell
az login
az account set --subscription "<subscription-id>"
$env:ARM_SUBSCRIPTION_ID = (az account show --query id --output tsv).Trim()
```

Prima di distribuire, si può verificare la SKU in `northeurope` con:

```powershell
az vm list-skus --location northeurope --resource-type virtualMachines --size Standard_B2s --all --output table
```

Verificare anche la SKU se si cambia regione o subscription. La disponibilità del catalogo non garantisce quota libera.

Verificare l'immagine configurata:

```powershell
az vm image show --location northeurope --urn Canonical:ubuntu-26_04-lts:server:latest --query "{version:name,architecture:architecture}" --output json
```

## Configurazione e deployment

Dalla directory del progetto:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Rivedere `terraform.tfvars`, in particolare i CIDR di SSH e Tomcat. La password non va aggiunta al file. Inserirla temporaneamente nell'ambiente del solo processo PowerShell:

```powershell
$securePassword = Read-Host "Password VM (12-123 caratteri)" -AsSecureString
$env:TF_VAR_admin_password = [System.Net.NetworkCredential]::new("", $securePassword).Password
try {
    terraform init
    terraform fmt -check
    terraform validate
    terraform plan -out=tfplan
    # Esaminare tfplan e applicarlo solo dopo averne approvato le modifiche.
    terraform apply tfplan
}
finally {
    Remove-Item Env:\TF_VAR_admin_password -ErrorAction SilentlyContinue
    Remove-Variable securePassword -ErrorAction SilentlyContinue
}
```

Il valore in una variabile d'ambiente è disponibile in chiaro al processo Terraform mentre il comando è in esecuzione. Per CI/CD, usare il secret store della piattaforma. Non eseguire `apply` senza aver esaminato il piano.

Comandi separati, se si preferisce:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

`terraform plan` e `terraform apply` richiedono la variabile `TF_VAR_admin_password` oppure un'altra modalità di input sicura. I piani salvati possono contenere dati sensibili. I comandi `terraform apply` creano risorse fatturabili; verificare il piano e i prezzi della regione prima di procedere.

## Verifica

Dopo il deployment, leggere gli output:

```powershell
terraform output
```

Verificare il servizio e l'applicazione:

```powershell
curl.exe -I "$(terraform output -raw tomcat_url)"
```

Se il bootstrap non è terminato, controllare `cloud-init status --long`, `/var/log/cloud-init-output.log` e `systemctl status tomcat10` via SSH. L'URL HTTP prova la raggiungibilità ma non protegge il traffico.

## Aggiornamenti e distruzione

`latest` per la versione immagine risolve l'ultima build del medesimo offer/SKU quando Terraform crea o ricrea la VM. Una VM esistente non viene automaticamente aggiornata all'immagine più recente. Modificare i parametri immagine solo dopo aver verificato la compatibilità e aver salvato dati e configurazioni.

Per rimuovere le risorse create dal progetto:

```powershell
terraform plan -destroy
terraform destroy
```

La distruzione elimina la VM e le risorse gestite da questa configurazione. Salvare prima eventuali dati necessari; controllare il piano di distruzione prima di confermare.

## Backend remoto

Per uso condiviso, configurare un backend `azurerm` in un account Storage Azure dedicato prima dell'inizializzazione: container privato, accesso minimo tramite Microsoft Entra ID/RBAC, rete limitata e protezione/versioning del blob secondo le policy dell'organizzazione. `terraform init -migrate-state` può migrare uno state locale esistente dopo aver configurato il backend; verificare la procedura e il backup prima della migrazione. Non salvare chiavi Storage o credenziali backend nel repository. La cifratura dello state non sostituisce i controlli di accesso.

## Riferimenti

- [Terraform language style](https://developer.hashicorp.com/terraform/language/style)
- [AzureRM Linux Virtual Machine](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine)
- [AzureRM Network Security Group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
- [AzureRM Network Interface](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface)
- [AzureRM Public IP](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip)
- [AzureRM Virtual Network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
- [AzureRM Subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)
- [Azure VM B-series sizes](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/b-family)
- [Azure Linux distributions endorsed](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/endorsed-distros)
- [Ubuntu release images](https://releases.ubuntu.com/)
- [Ubuntu 26.04 Tomcat 10 package](https://packages.ubuntu.com/resolute/tomcat10)
- [Ubuntu 26.04 OpenJDK 21 package](https://packages.ubuntu.com/resolute/openjdk-21-jdk-headless)
