#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Falha na linha $LINENO. Corrija o erro antes de repetir." >&2' ERR

# Execute como usuario da sessao grafica, sem sudo na chamada principal.
[[ $EUID -ne 0 ]] || { echo 'Execute como usuario normal: bash install.sh URL_OVA SHA256'; exit 1; }
[[ $# -eq 2 ]] || { echo 'Uso: bash install.sh https://servidor/7SN_x64.ova SHA256'; exit 1; }
OVA_URL=$1
OVA_SHA=$2
[[ $OVA_URL == https://* && $OVA_SHA =~ ^[a-fA-F0-9]{64}$ ]] || { echo 'Informe URL HTTPS e SHA256 valido.'; exit 1; }
source /etc/os-release
[[ $ID == ubuntu && ${VERSION_CODENAME:-} =~ ^(focal|jammy)$ ]] || { echo 'Suportado: Ubuntu 20.04 focal ou 22.04 jammy.'; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'Esta OVA requer host x86_64.'; exit 1; }
grep -Eq '(vmx|svm)' /proc/cpuinfo || { echo 'Virtualizacao de hardware indisponivel. Verifique BIOS/UEFI.'; exit 1; }

VM='Touch-Manutencao'
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/touch-maintenance"
mkdir -p "$DATA" "$HOME/.local/bin" "$HOME/.local/share/applications"
sudo -v
sudo apt-get update
sudo apt-get install -y software-properties-common ca-certificates wget
sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse
sudo apt-get update
sudo apt-get install -y "linux-headers-$(uname -r)" virtualbox virtualbox-qt
sudo usermod -aG vboxusers "$(id -un)"

# Nao aceita licencas automaticamente. O pacote apresenta seus termos.
if ! VBoxManage list extpacks | grep -q 'Usable: *true'; then
  echo 'USB 2.0 exige Extension Pack compativel. Confira o licenciamento para uso empresarial.'
  echo 'Se houver autorizacao/licenca aplicavel, instale pelo gerenciador do VirtualBox ou pacote adequado.'
  echo 'A configuracao pode continuar depois: execute novamente este script.'
  exit 2
fi
sudo modprobe vboxdrv || { echo 'Modulo vboxdrv indisponivel. Confira DKMS/Secure Boot antes de continuar.'; exit 1; }

IMPORTED=false
if ! VBoxManage showvminfo "$VM" >/dev/null 2>&1; then
  if [[ ! -f "$DATA/base.ova" ]] || ! printf '%s  %s\n' "$OVA_SHA" "$DATA/base.ova" | sha256sum -c - >/dev/null 2>&1; then
    wget --https-only -O "$DATA/base.ova.part" "$OVA_URL"
    printf '%s  %s\n' "$OVA_SHA" "$DATA/base.ova.part" | sha256sum -c -
    mv "$DATA/base.ova.part" "$DATA/base.ova"
  fi
  VBoxManage import "$DATA/base.ova" --vsys 0 --vmname "$VM"
  IMPORTED=true
fi
INFO=$(VBoxManage showvminfo "$VM" --machinereadable)
grep -q '^VMState="poweroff"$' <<< "$INFO" || { echo 'Desligue a VM completamente antes de configurar.'; exit 1; }
# Somente a VM dedicada; nunca altera filtros globais ou outras VMs.
if [[ $IMPORTED == true ]]; then
COUNT=$(grep -c '^USBFilterName[0-9]*=' <<< "$INFO" || true)
for ((i=COUNT-1; i>=0; i--)); do VBoxManage usbfilter remove "$i" --target "$VM"; done

VBoxManage usbfilter add 0 --target "$VM" --name 'eGalax normal' --vendorid 0eef --productid c002
VBoxManage usbfilter add 1 --target "$VM" --name 'eGalax bootloader' --vendorid 0eef --productid 79fd
fi
VBoxManage modifyvm "$VM" --memory 1024 --cpus 1 --nic1 none --usb on --usbehci on

cat > "$HOME/.local/bin/touch-maintenance" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
if ! id -nG | tr ' ' '\n' | grep -qx vboxusers; then
  echo 'Encerre a sessao do Ubuntu e entre novamente para liberar o acesso USB.'
  read -r -p 'Enter para fechar.'
  exit 1
fi
exec VBoxManage startvm 'Touch-Manutencao' --type gui
LAUNCHER
chmod +x "$HOME/.local/bin/touch-maintenance"
cat > "$HOME/.local/share/applications/touch-maintenance.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Manutencao do Touch
Comment=Ambiente Windows para eGalax e ILITEK
Exec="$HOME/.local/bin/touch-maintenance"
Terminal=true
Icon=computer
Categories=System;
DESKTOP
echo 'Importacao e configuracao concluidas. Encerre a sessao e entre novamente antes de usar USB.'
echo 'ILITEK ainda requer identificacao USB e validacao. Nenhum firmware foi gravado.'
