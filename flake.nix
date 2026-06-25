{
  description = "Config home-manager (standalone) — Debian + Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager standalone. O `follows` faz o home-manager usar
    # EXATAMENTE o mesmo nixpkgs acima (evita baixar 2 versões).
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code.url = "github:sadjow/claude-code-nix";
    herdr.url = "github:ogulcancelik/herdr";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

      # Valores específicos da máquina — gerados por ./init.sh.
      # (username, hostname, homeDirectory)
      settings = import ./settings.nix;
      inherit (settings) username hostname homeDirectory;

      # allowUnfree garante que pacotes "não livres" (ex.: claude-code) avaliem.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # Convenção do home-manager: "usuario@servidor".
      # Sem alvo, `home-manager switch --flake .` resolve pra $USER@$(hostname).
      homeConfigurations."${username}@${hostname}" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs system username hostname homeDirectory; };
          modules = [ ./home.nix ];
        };
    };
}
