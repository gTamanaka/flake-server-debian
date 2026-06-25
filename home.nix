{ config, pkgs, lib, inputs, system, username, hostname, homeDirectory, ... }:

{
  # --- Identidade do usuário gerenciado (vem de settings.nix via init.sh) ---
  home.username = username;
  home.homeDirectory = homeDirectory;

  # NÃO mude isto depois de aplicar a primeira vez.
  # É só um marcador de compatibilidade, não a versão do home-manager.
  home.stateVersion = "25.05";

  # ============================================================
  # PACOTES — tudo que você quer disponível no PATH do usuário.
  # ============================================================
  home.packages = [
    # Pacotes que vêm dos seus flakes (inputs):
    inputs.claude-code.packages.${system}.default
    inputs.herdr.packages.${system}.default

    # Pacotes normais do nixpkgs (adicione/remova à vontade):
    pkgs.ripgrep
    pkgs.fd
    pkgs.htop
    pkgs.git
    pkgs.tmux
  ];

  # ============================================================
  # PROGRAMAS — módulos do home-manager que, além de instalar,
  # também GERAM os arquivos de config automaticamente.
  # ============================================================
  programs.git = {
    enable = true;
    settings.user = {
      name = "Gustavo";
      email = "tamanaka.gustavo@gmail.com";
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -alh";
      hm = "home-manager switch --flake ~/srv1779435";
    };
  };

  # Deixa o próprio home-manager se autogerenciar (recomendado no standalone).
  programs.home-manager.enable = true;
}
