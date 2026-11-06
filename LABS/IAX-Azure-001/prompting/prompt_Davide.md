Agisci come un Senior Cloud DevOps Engineer esperto in Infrastructure as Code (IaC), Terraform e Microsoft Azure.
Il tuo compito è generare un progetto Terraform completo, modulare e conforme alle best practice per il provisioning di una Virtual Machine Linux su Azure.
 
### REQUISITI INFRASTRUTTURALI ###
1. Sistema Operativo: Ubuntu LTS (ultima versione disponibile). NON hardcodare la versione dell'immagine. Usa un 'data source' (azurerm_linux_web_application_firewall_policy o azurerm_image / publisher/offer/sku) per recuperare dinamicamente l'ultima immagine LTS di Canonical.
2. Compute: Virtual Machine con esattamente 2 vCPU e 4 GB di RAM (utilizza la SKU 'Standard_D2s_v3' o 'Standard_B2s').
3. Networking: 
   - Virtual Network (VNet) e Subnet dedicate.
   - Network Security Group (NSG) configurato per permettere in ingresso solo SSH (porta 22) e HTTPS (porta 443).
   - Public IP Standard (Sku = Standard) associato alla NIC.
   - Network Interface Card (NIC).
4. Storage: OS Disk gestito (Managed Disk) con tipo 'Standard_LRS' o 'Premium_LRS'.
 
### REQUISITI DI CODICE E DEVOPS BEST PRACTICES ###
1. Struttura del progetto: Separa il codice nei seguenti file:
   - versions.tf (provider azurerm con vincoli di versione rigorosi, es. ~> 3.0 o 4.0 a tua scelta, e required_version per Terraform).
   - variables.tf (dichiara tutte le variabili con tipo, descrizione e default dove appropriato).
   - main.tf (risorse e data source).
   - outputs.tf (es. IP pubblico della VM, ID della VM).
2. Sicurezza: L'accesso alla VM deve avvenire ESCLUSIVAMENTE tramite chiave pubblica SSH. Non prevedere l'uso di password. La chiave pubblica SSH deve essere iniettata tramite variabile.
3. Tagging: Implementa una variabile 'common_tags' (map) e applicala a tutte le risorse supportate (es. Environment, Project, ManagedBy = "Terraform").
4. Variabilizzazione: Resource Group Name, Location, VM Name e SSH Public Key devono essere variabili obbligatorie o con default sensati.
5. File di supporto: Genera il contenuto per un file 'terraform.tfvars.example' e un 'README.md' con i prerequisiti (es. login ad Azure) e i comandi di deploy (init, plan, apply).
 
### OUTPUT RICHIESTO ###
Fornisci il codice HCL completo per ogni file richiesto, ben commentato, sintatticamente corretto e pronto per essere copiato e incollato. Assicurati che il data source per Ubuntu sia corretto e funzionante con l'attuale provider azurerm.