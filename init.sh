#!/usr/bin/env bash
#
# init.sh — detecta usuário/servidor da máquina atual, configura este flake,
#           aplica o home-manager e prepara o shell pra enxergar os binários.
#
#   ./init.sh            -> gera settings.nix + prepara o shell, mostra próximo passo
#   ./init.sh --apply    -> faz o acima E já aplica a config (1ª vez, via nix run)
#
# Overrides (caso a autodetecção não sirva):
#   HM_USER=fulano HM_HOST=meuserver HM_HOME=/home/fulano ./init.sh --apply
#
set -euo pipefail

# Vai pro diretório do próprio script (funciona de qualquer lugar).
cd "$(dirname "$(readlink -f "$0")")"

# Bloco que ensina o shell a achar os binários do home-manager (standalone).
# Marcado pra ser idempotente: só é inserido se ainda não existir no arquivo.
HM_MARKER="# >>> home-manager env (init.sh) >>>"
read -r -d '' HM_BLOCK <<'EOF' || true
# >>> home-manager env (init.sh) >>>
HM_PROFILE="$HOME/.local/state/nix/profiles/home-manager/home-path"
[ -d "$HM_PROFILE/bin" ] && export PATH="$HM_PROFILE/bin:$PATH"
[ -e "$HM_PROFILE/etc/profile.d/hm-session-vars.sh" ] && . "$HM_PROFILE/etc/profile.d/hm-session-vars.sh"
# <<< home-manager env (init.sh) <<<
EOF

# Insere o bloco em $1 se ainda não estiver lá (sem abortar se não der pra escrever).
ensure_block() {
  local file="$1"
  if grep -qsF "$HM_MARKER" "$file" 2>/dev/null; then
    echo "      (já configurado em $file)"
  elif printf '\n%s\n' "$HM_BLOCK" >> "$file" 2>/dev/null; then
    echo "      + bloco adicionado em $file"
  else
    echo "      ! sem permissão pra escrever em $file (pulei)"
  fi
}

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

# 4) Prepara o shell de login (e o interativo) pra achar os binários do HM.
echo "==> Preparando o shell (PATH + variáveis de sessão):"
ensure_block "$HOME/.profile"
ensure_block "$HOME/.bashrc"

# 5) Se for um repo git, deixa o settings.nix visível pro nix (flakes só
#    enxergam arquivos rastreados/staged dentro de um git tree).
if [ -d .git ]; then
  git add settings.nix 2>/dev/null || true
fi

TARGET="$USERNAME@$HOSTNAME_VAL"

# 6) Aplica agora se pediram --apply; senão, só instrui.
if [ "${1:-}" = "--apply" ]; then
  echo "==> Aplicando pela primeira vez (via 'nix run')..."
  nix run home-manager/master -- switch --flake ".#$TARGET"
  echo
  echo "==> Pronto! Recarregue o shell pra usar os binários:"
  echo "      exec bash -l"
  echo "    Depois confira: which claude herdr home-manager"
else
  echo
  echo "Próximo passo — primeira aplicação:"
  echo "      nix run home-manager/master -- switch --flake .#$TARGET"
  echo "  (ou rode: ./init.sh --apply  para fazer isso automaticamente)"
  echo
  echo "Depois de aplicar, recarregue o shell: exec bash -l"
fi
