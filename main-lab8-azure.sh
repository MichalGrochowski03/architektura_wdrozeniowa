#!/bin/bash

set -e

# 1. PARAMETRY DOMYŚLNE
LOCATION=${1:-polandcentral}

APP_VM="240095-app"
DB_VM="240095-db"
ADMIN_USER="ia-admin"

echo ""
echo "============================================================"
echo "ROZPOCZYNAM PEŁNE TWORZENIE ŚRODOWISKA LAB 8"
echo "VM aplikacyjna: $APP_VM"
echo "VM bazodanowa: $DB_VM"
echo "Region: $LOCATION"
echo "============================================================"

# 2. TWORZENIE MASZYNY APLIKACYJNEJ
echo ""
echo "Krok 1: Tworzenie maszyny aplikacyjnej..."
./utworz_app_azure.sh "$APP_VM" "$LOCATION"

# 3. TWORZENIE MASZYNY BAZODANOWEJ
echo ""
echo "Krok 2: Tworzenie maszyny bazodanowej..."
./utworz_db_azure.sh "$DB_VM" "$LOCATION"

# 4. WCZYTANIE ADRESÓW IP Z PLIKÓW
APP_IP=$(cat app_ip.txt)
DB_IP=$(cat db_ip.txt)

APP_RG=$(cat app_rg.txt)
DB_RG=$(cat db_rg.txt)

echo ""
echo "============================================================"
echo "POBRANE ADRESY IP"
echo "IP APP: $APP_IP"
echo "IP DB: $DB_IP"
echo "============================================================"

# 5. OTWARCIE PORTU POSTGRESQL 5432 TYLKO DLA IP APLIKACJI
echo ""
echo "Krok 3: Otwieranie portu PostgreSQL 5432 na DB tylko dla IP aplikacji..."

DB_NIC_ID=$(az vm show \
  -g "$DB_RG" \
  -n "$DB_VM" \
  --query "networkProfile.networkInterfaces[0].id" \
  -o tsv)

DB_NIC_NAME=$(basename "$DB_NIC_ID")

DB_NSG_ID=$(az network nic show \
  -g "$DB_RG" \
  -n "$DB_NIC_NAME" \
  --query "networkSecurityGroup.id" \
  -o tsv)

DB_NSG_NAME=$(basename "$DB_NSG_ID")

az network nsg rule create \
  --resource-group "$DB_RG" \
  --nsg-name "$DB_NSG_NAME" \
  --name Allow-PostgreSQL-From-App \
  --priority 1002 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "$APP_IP" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 5432 \
  --output none

echo "Port 5432 został otwarty na DB tylko dla IP aplikacji: $APP_IP"

# 6. DODANIE KLUCZY SSH DO known_hosts
echo ""
echo "Krok 4: Dodawanie kluczy SSH do known_hosts..."

mkdir -p ~/.ssh
ssh-keyscan -H "$APP_IP" >> ~/.ssh/known_hosts 2>/dev/null
ssh-keyscan -H "$DB_IP" >> ~/.ssh/known_hosts 2>/dev/null

# 7. TWORZENIE PEŁNEGO hosts.ini
echo ""
echo "Krok 5: Tworzenie pełnego pliku hosts.ini..."

cat > hosts.ini <<EOF
[app_servers]
app_node_1 ansible_host=$APP_IP ansible_user=$ADMIN_USER

[db_servers]
db_node_1 ansible_host=$DB_IP ansible_user=$ADMIN_USER

[storage_servers]
app_node_1 ansible_host=$APP_IP ansible_user=$ADMIN_USER

[srodowisko_dev:children]
app_servers
db_servers
storage_servers

[app_servers:vars]
backend_port=1234
nginx_port=80

[db_servers:vars]
db_port=5432
env_type=development

[storage_servers:vars]
minio_port=9000
minio_console_port=9001
EOF

echo "Plik hosts.ini został utworzony."

# 8. TEST POŁĄCZENIA ANSIBLE
echo ""
echo "Krok 6: Test połączenia Ansible ze wszystkimi maszynami..."

ansible all -i hosts.ini -m ping -k

# 9. URUCHOMIENIE GŁÓWNEGO PLAYBOOKA
echo ""
echo "Krok 7: Uruchamianie main.yml..."

ansible-playbook -i hosts.ini main.yml -k -K --ask-vault-pass

# 10. PODSUMOWANIE
echo ""
echo "============================================================"
echo "ŚRODOWISKO LAB 8 ZOSTAŁO UTWORZONE I SKONFIGUROWANE"
echo "APP VM: $APP_VM"
echo "APP IP: $APP_IP"
echo "DB VM: $DB_VM"
echo "DB IP: $DB_IP"
echo "============================================================"

echo ""
echo "Podgląd maszyn:"

az vm show \
  -d \
  -g "$APP_RG" \
  -n "$APP_VM" \
  --query "{name:name, location:location, size:hardwareProfile.vmSize, powerState:powerState, publicIp:publicIps}" \
  -o table

az vm show \
  -d \
  -g "$DB_RG" \
  -n "$DB_VM" \
  --query "{name:name, location:location, size:hardwareProfile.vmSize, powerState:powerState, publicIp:publicIps}" \
  -o table
