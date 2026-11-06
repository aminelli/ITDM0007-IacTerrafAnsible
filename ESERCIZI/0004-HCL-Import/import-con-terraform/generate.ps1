rg="rg-demo-dev"
sub=$(az account show --query id -o tsv)
out="ids-$rg.txt"

echo "/subscriptions/$sub/resourceGroups/$rg" > "$out"
az resource list -g "$rg" --query "[].id" -o tsv >> "$out"

for v in $(az network vnet list -g "$rg" --query "[].name" -o tsv); do
  az network vnet subnet list -g "$rg" --vnet-name "$v" --query "[].id" -o tsv >> "$out"
done

for st in $(az storage account list -g "$rg" --query "[].id" -o tsv); do
  az rest --method get \
    --url "https://management.azure.com${st}/blobServices/default/containers?api-version=2023-05-01" \
    --query "value[].id" -o tsv >> "$out"
done

for vm in $(az vm list -g "$rg" --query "[].id" -o tsv); do
  for d in $(az monitor diagnostic-settings list --resource "$vm" --query "value[].name" -o tsv); do
    echo "$vm|$d" >> "$out"
  done
done

sort -u "$out" | grep -v '/disks/' > "$out.tmp" && mv "$out.tmp" "$out"
wc -l "$out"