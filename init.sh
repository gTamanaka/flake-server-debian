#!/usr/bin/env bash
#
# init.sh — detecta usuário/servidor da máquina atual e configura este flake.
#
#   ./init.sh            -> só gera settings.nix e mostra o próximo passo
#   ./init.sh --apply    -> gera settings.nix E já aplica a config (1ª vez)
#
# Overrides (caso a autodetecção não sirva):
#   HM_USER=fulano HM_HOST=meuserver HM_HOME=/home/fulano ./init.sh
#
set -euo pipefail

# Vai pro diretório do próprio script (funciona de qualquer lugar).
cd "$(dirname "$(readlink -f "$0")")"

# 1) Autodetecta (com possibilidade de override por variável de ambiente).
USERNAME="${HM_USER:-$(id -un)}"
HOSTNAME_VAL="${HM_HOST:-$(hostname -s 2>/dev/null || hostname)}"
HOMEDIR="${HM_HOME:-$HOME}"

echo "==> Configurando home-manager para esta máquina:"
echo "      usuário   = $USERNAME"
echo "      servidor  = $HOSTNAME_VAL"
echo "      \$HOME      = $HOMEDIR"

# 2) Gera o settings.nix que o flake.nix lê.
cat > settings.nix <<EOF
# Gerado por ./init.sh — não edite à mão (rode init.sh de novo).
{
  username = "$USERNAME";
  hostname = "$HOSTNAME_VAL";
  homeDirectory = "$HOMEDIR";
}
EOF
echo "==> settings.nix atualizado."

# 3) Garante que nix-command + flakes estão habilitados pro usuário.
NIX_CONF="$HOME/.config/nix/nix.conf"
if ! grep -qs "flakes" "$NIX_CONF" 2>/dev/null; then
  mkdir -p "$(dirname "$NIX_CONF")"
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
  echo "==> flakes habilitados em $NIX_CONF"
fi

# 4) Se for um repo git, deixa o settings.nix visível pro nix (flakes só
#    enxergam arquivos rastreados/staged dentro de um git tree).
if [ -d .git ]; then
  git add settings.nix 2>/dev/null || true
fi

TARGET="$USERNAME@$HOSTNAME_VAL"

# 5) Aplica agora se pediram --apply; senão, só instrui.
if [ "${1:-}" = "--apply" ]; then
  echo "==> Aplicando pela primeira vez (via 'nix run')..."
  nix run home-manager/master -- switch --flake ".#$TARGET"
  echo
  echo "==> Pronto! Carregue o ambiente nesta sessão com:"
  echo '      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"'
  echo "    (ou só reabra o shell)"
else
  echo
  echo "Próximo passo — primeira aplicação:"
  echo "      nix run home-manager/master -- switch --flake .#$TARGET"
  echo "  (ou rode: ./init.sh --apply  para fazer isso automaticamente)"
  echo
  echo "Depois da 1ª vez, o ciclo do dia a dia é só:"
  echo "      home-manager switch --flake ."
fi
