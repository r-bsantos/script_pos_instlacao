#!/bin/bash

# Encerra o script em caso de erro
set -eo pipefail

# Verificação de privilégios de superusuário
if [ "$EUID" -ne 0 ]; then
    echo "Erro: Execute este script com privilégios de superusuário (sudo)."
    exit 1
fi

# Obter o usuário real (que executou o sudo)
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "==> Iniciando configuração pós-instalação para o usuário: $REAL_USER"

# Modo não interativo para instalações de pacotes
export DEBIAN_FRONTEND=noninteractive

# 1. Atualizar repositórios e sistema
echo "==> Atualizando lista de pacotes..."
apt update && apt upgrade -y

# 2. Instalar dependências básicas
apt install -y curl wget gpg software-properties-common ca-certificates

# 3. Adicionar repositório oficial do Microsoft Edge (Método Keyring Moderno)
echo "==> Configurando repositório do Microsoft Edge..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge.list

# Atualizar índice após adicionar o novo repositório
apt update

# 4. Instalação em lote de pacotes APT
echo "==> Instalando pacotes APT..."
apt install -y \
    mariadb-server \
    mysql-workbench \
    default-jdk \
    grass \
    gparted \
    vim \
    git \
    gnome-software gnome-software-plugin-flatpak gnome-software-plugin-snap \
    kdeconnect \
    openssh-server \
    microsoft-edge-stable

# 5. Instalação de pacotes SNAP
echo "==> Instalando pacotes Snap..."
snap install code --classic
snap install netbeans --classic
snap install pycharm-professional --classic
snap install dbeaver-ce

# 6. Configuração das Extensões do Firefox via Políticas Corporativas
echo "==> Configurando extensões do Firefox..."
FIREFOX_POLICY_DIR="/etc/firefox/policies"
mkdir -p "$FIREFOX_POLICY_DIR"

cat <<'EOF' > "$FIREFOX_POLICY_DIR/policies.json"
{
  "policies": {
    "ExtensionSettings": {
      "{446900e4-71c2-419f-a6a7-df9c091e268b}": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi"
      },
      "uBlock0@raymondhill.net": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      },
      "@testpilot-containers": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi"
      },
      "{10381373-1fcf-49b0-b98a-2be8cd1d46b8}": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/malwarebytes/latest.xpi"
      }
    }
  }
}
EOF

# 7. Configuração do Git para o usuário comum
echo "==> Configurando Git..."
sudo -u "$REAL_USER" git config --global user.name "Seu Nome"
sudo -u "$REAL_USER" git config --global user.email "seu_email@example.com"

# 8. Gerenciamento do SSH
echo "==> Configurando serviço SSH..."
systemctl enable --now ssh

SSH_DIR="$REAL_HOME/.ssh"
if [ ! -f "$SSH_DIR/id_rsa" ]; then
    echo "==> Gerando chave SSH RSA de 4096 bits..."
    sudo -u "$REAL_USER" mkdir -p "$SSH_DIR"
    sudo -u "$REAL_USER" chmod 700 "$SSH_DIR"
    sudo -u "$REAL_USER" ssh-keygen -t rsa -b 4096 -C "seu_email@example.com" -f "$SSH_DIR/id_rsa" -N ""
else
    echo "==> Uma chave SSH já existe em $SSH_DIR/id_rsa. Mantendo chave atual."
fi

# 9. Limpeza final
echo "==> Efetuando limpeza de pacotes e caches..."
apt autoremove -y
apt clean

echo "==> Instalação e configuração concluídas com sucesso!"
