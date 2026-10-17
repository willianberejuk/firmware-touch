#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Falha na linha $LINENO. Corrija o erro antes de repetir." >&2' ERR

# Execute como usuario da sessao grafica, sem sudo na chamada principal.
[[ $EUID -ne 0 ]] || { echo 'Execute como usuario normal: bash install.sh URL_OVA SHA256'; exit 1; }
[[ $# -eq 0 || $# -eq 2 ]] || { echo 'Uso: bash install.sh https://servidor/7SN_x64.ova SHA256'; exit 1; }
OVA_URL=${1:-https://github.com/willianberejuk/firmware-touch/releases/download/v0.1.0/Touch-Manutencao.ova}
OVA_SHA=${2:-739234ced6189459c53a575abb29faf59ea70e7c626fab4c199cb2555688ed59}
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
sudo apt-get install -y ca-certificates wget gnupg build-essential dkms "linux-headers-$(uname -r)"
wget --https-only -O "$DATA/oracle.asc" https://www.virtualbox.org/download/oracle_vbox_2016.asc
sudo gpg --yes --dearmor --output /usr/share/keyrings/oracle-virtualbox.gpg "$DATA/oracle.asc"
printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox.gpg] https://download.virtualbox.org/virtualbox/debian %s contrib\n' "$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/oracle-virtualbox.list
sudo apt-get update
PACKAGE=''
for candidate in virtualbox-7.2 virtualbox-7.1 virtualbox-7.0; do
  available=$(apt-cache policy "$candidate" | awk '/Candidate:|Candidato:/ {print $2}')
  if [[ -n $available && $available != '(none)' && $available != '(nenhum)' ]]; then
    PACKAGE=$candidate
    break
  fi
done
[[ -n $PACKAGE ]] || { echo 'Nenhuma versao Oracle disponivel para este Ubuntu.'; exit 1; }
if command -v VBoxManage >/dev/null; then
  [[ -z $(VBoxManage list runningvms) ]] || { echo 'Desligue todas as VMs e feche o VirtualBox antes de continuar.'; exit 1; }
fi
old_packages=()
for pkg in virtualbox virtualbox-qt virtualbox-dkms virtualbox-ext-pack; do
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -qx 'install ok installed'; then old_packages+=("$pkg"); fi
done
if ((${#old_packages[@]})); then sudo apt-get remove -y "${old_packages[@]}"; fi
sudo apt-get install -y "$PACKAGE"
sudo usermod -aG vboxusers "$(id -un)"
sudo modprobe vboxdrv || { echo 'Verifique DKMS/Secure Boot e reinicie antes de repetir.'; exit 1; }
VERSION=$(VBoxManage --version | cut -d r -f 1)
LOADED=$(cat /sys/module/vboxdrv/version)
if [[ $LOADED != "$VERSION "* && $LOADED != "$VERSION" ]]; then
  echo 'O modulo carregado ainda e antigo. Reinicie o Ubuntu e execute este script novamente.'
  exit 2
fi
PACKS=$(VBoxManage list extpacks)
if ! awk -v version="$VERSION" '
 /^Pack no\./ {oracle=($0 ~ /Oracle.*VirtualBox.*Extension Pack/); matched=0}
 /^Version:/ {matched=($2==version)}
 /^Usable:/ {if (oracle && matched && $2=="true") found=1}
 END {exit !found}' <<< "$PACKS"; then
  EXT="Oracle_VirtualBox_Extension_Pack-${VERSION}.vbox-extpack"
  wget --https-only -O "$DATA/$EXT" "https://download.virtualbox.org/virtualbox/$VERSION/$EXT"
  wget --https-only -O "$DATA/SHA256SUMS" "https://download.virtualbox.org/virtualbox/$VERSION/SHA256SUMS"
  (cd "$DATA"; awk -v file="$EXT" '$2==file || $2=="*"file {print; found=1} END {if (!found) exit 1}' SHA256SUMS > extpack.sha256; sha256sum -c extpack.sha256)
  # Apresenta os termos para aceite interativo.
  sudo VBoxManage extpack install --replace "$DATA/$EXT"
fi

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
# Preserva todos os filtros contidos na OVA, inclusive ILITEK.
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
echo 'Filtros da OVA preservados. Nenhum firmware foi gravado.'
