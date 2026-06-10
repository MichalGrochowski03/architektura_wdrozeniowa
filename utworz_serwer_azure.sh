#!/bin/bash

# ==============================================================================
# Skrypt: Tworzenie infrastruktury w chmurze Azure (Grupa Zasobów + VM)
# Autoryzacja: Logowanie za pomocą hasła podawanego interaktywnie
# ==============================================================================

set -e

if [ -z "$1" ]; then
  echo "Błąd: Nie podano nazwy maszyny wirtualnej!"
  echo "Użycie: ./utworz_serwer_azure.sh [NAZWA_MASZYNY] [LOKALIZACJA_OPCJONALNA]"
  echo "Przykład: ./utworz_serwer_azure.sh prod-baza westeurope"
  exit 1
fi

# 2. PARAMETRY WEJŚCIOWE I DOMYŚLNE WARTOSCI
VM_NAME=$1
LOCATION=${2:-polandcentral} 

RG_NAME="rg-ia-lab-${VM_NAME}" 
IMAGE="Ubuntu2204"
ADMIN_USER="ia-admin"
SIZE="Standard_B2s_V2" 

# 3. BEZPIECZNE POBIERANIE HASŁA OD UŻYTKOWNIKA
# Flaga -s (silent) ukrywa wpisywane znaki na ekranie
echo -n "Podaj hasło dla nowej maszyny: "
read -s VM_PASSWORD
echo "" # Dodajemy pustą linię, aby terminal ładnie wyglądał po wciśnięciu Enter


echo "======================================================"
echo "ROZPOCZYNAM BUDOWĘ INFRASTRUKTURY (Tryb: Hasło)"
echo "Maszyna: $VM_NAME"
echo "Region: $LOCATION"
echo "Grupa zasobów: $RG_NAME"
echo "======================================================"

# 4. TWORZENIE GRUPY ZASOBÓW
echo "Krok 1: Tworzenie lub weryfikacja Grupy Zasobów..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --output none

# 5. TWORZENIE MASZYNY WIRTUALNEJ Z HASŁEM
echo "Krok 2: Tworzenie maszyny wirtualnej w regionie $LOCATION..."
echo "To może potrwać od 1 do 3 minut..."

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

echo "Maszyna została pomyślnie utworzona!"

# 6. POBRANIE PUBLICZNEGO ADRESU IP
VM_IP=$(az vm show -d -g "$RG_NAME" -n "$VM_NAME" --query publicIps -o tsv)

echo "------------------------------------------------------"
echo "Publiczny adres IP serwera: $VM_IP"
echo "Połącz się ręcznie: ssh $ADMIN_USER@$VM_IP"
echo "------------------------------------------------------"
