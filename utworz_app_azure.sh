#!/bin/bash

set -e

# 1. SPRAWDZENIE PARAMETRÓW
if [ -z "$1" ]; then
  echo "Błąd: Nie podano nazwy maszyny aplikacyjnej!"
  echo "Użycie: ./stworz-aplikacje.sh [NAZWA_MASZYNY] [LOKALIZACJA_OPCJONALNA]"
  echo "Przykład: ./stworz-aplikacje.sh 240095-app polandcentral"
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
echo -n "Podaj hasło dla nowej maszyny aplikacyjnej: "
read -s VM_PASSWORD
echo ""

echo ""
echo "============================================================"
echo "ROZPOCZYNAM BUDOWĘ MASZYNY APLIKACYJNEJ"
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
echo "Krok 2: Tworzenie maszyny wirtualnej APP..."
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

# 6. OTWIERANIE PORTÓW DLA APLIKACJI
echo "Krok 3: Otwieranie portów dla aplikacji..."

az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 22 \
  --priority 1001 \
  --output none

az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 80 \
  --priority 1002 \
  --output none

az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 1234 \
  --priority 1003 \
  --output none

az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 5000 \
  --priority 1004 \
  --output none

az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 9000 \
  --priority 1005 \
  --output none

az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 9001 \
  --priority 1006 \
  --output none

# 7. POBRANIE ADRESU IP
APP_IP=$(az vm show \
  -d \
  -g "$RG_NAME" \
  -n "$VM_NAME" \
  --query publicIps \
  -o tsv)

# 8. ZAPISANIE IP DO PLIKU
echo "$APP_IP" > app_ip.txt
echo "$RG_NAME" > app_rg.txt
echo "$VM_NAME" > app_vm.txt

# 9. DODANIE KLUCZA SSH DO known_hosts
echo "Dodawanie klucza SSH APP do known_hosts..."
mkdir -p ~/.ssh
ssh-keyscan -H "$APP_IP" >> ~/.ssh/known_hosts 2>/dev/null

echo ""
echo "============================================================"
echo "MASZYNA APLIKACYJNA ZOSTAŁA UTWORZONA"
echo "Nazwa VM: $VM_NAME"
echo "Grupa zasobów: $RG_NAME"
echo "Publiczny adres IP APP: $APP_IP"
echo "Połącz się: ssh $ADMIN_USER@$APP_IP"
echo "============================================================"
