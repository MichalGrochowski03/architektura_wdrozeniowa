#!/bin/bash

set -e

# 1. SPRAWDZENIE PARAMETRÓW
if [ -z "$1" ]; then
  echo "Błąd: Nie podano nazwy maszyny bazodanowej!"
  echo "Użycie: ./stworz-db.sh [NAZWA_MASZYNY] [LOKALIZACJA_OPCJONALNA]"
  echo "Przykład: ./stworz-db.sh 240095-db polandcentral"
  exit 1
fi

# 2. PARAMETRY WEJŚCIOWE I DOMYŚLNE WARTOŚCI
VM_NAME=$1
LOCATION=${2:-polandcentral}

RG_NAME="rg-ia-lab-${VM_NAME}"
IMAGE="Ubuntu2204"
ADMIN_USER="ia-admin"
SIZE="Standard_B2s_V2"

# 3. BEZPIECZNE POBIERANIE HASŁA OD UŻYTKOWNIKA
echo -n "Podaj hasło dla nowej maszyny bazodanowej: "
read -s VM_PASSWORD
echo ""

echo ""
echo "============================================================"
echo "ROZPOCZYNAM BUDOWĘ MASZYNY BAZODANOWEJ"
echo "Maszyna: $VM_NAME"
echo "Region: $LOCATION"
echo "Grupa zasobów: $RG_NAME"
echo "============================================================"

# 4. TWORZENIE GRUPY ZASOBÓW
echo "Krok 1: Tworzenie lub weryfikacja Grupy Zasobów..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --output none

# 5. TWORZENIE MASZYNY WIRTUALNEJ
echo "Krok 2: Tworzenie maszyny wirtualnej DB..."
az vm create \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --name "$VM_NAME" \
  --image "$IMAGE" \
  --size "$SIZE" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$VM_PASSWORD" \
  --public-ip-sku Standard \
  --output none

# 6. OTWIERANIE PORTU SSH
echo "Krok 3: Otwieranie portu SSH 22..."
az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 22 \
  --priority 1001 \
  --output none

# 7. POBRANIE ADRESU IP
DB_IP=$(az vm show \
  -d \
  -g "$RG_NAME" \
  -n "$VM_NAME" \
  --query publicIps \
  -o tsv)

# 8. ZAPISANIE IP DO PLIKU
echo "$DB_IP" > db_ip.txt
echo "$RG_NAME" > db_rg.txt
echo "$VM_NAME" > db_vm.txt

# 9. DODANIE KLUCZA SSH DO known_hosts
echo "Dodawanie klucza SSH DB do known_hosts..."
mkdir -p ~/.ssh
ssh-keyscan -H "$DB_IP" >> ~/.ssh/known_hosts 2>/dev/null

echo ""
echo "============================================================"
echo "MASZYNA BAZODANOWA ZOSTAŁA UTWORZONA"
echo "Nazwa VM: $VM_NAME"
echo "Grupa zasobów: $RG_NAME"
echo "Publiczny adres IP DB: $DB_IP"
echo "Połącz się: ssh $ADMIN_USER@$DB_IP"
echo "============================================================"
