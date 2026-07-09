function flakeinit --description 'Scaffold flake.nix (devShell vacio) para nix develop'
    set -l target flake.nix
    if test -e $target
        echo "flakeinit: $target ya existe, no se sobreescribe" >&2
        return 1
    end

    echo '{
  description = "Project dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # Paquetes del proyecto — agregar aqui
        # (nodejs_22, python3, uv, go, rustup, gcc, pkg-config, ...)
        packages = with pkgs; [ ];

        # Variables de entorno del shell
        env = { };

        shellHook = \'\'
          echo "dev shell: $PWD"
        \'\';
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}' >$target

    # nix flakes ignoran archivos untracked: sin esto `nix develop`
    # falla con "path does not exist" dentro de un repo git.
    if test -d .git
        git add --intent-to-add $target
        echo "flakeinit: $target creado y agregado al index de git"
    else
        echo "flakeinit: $target creado"
    end
    echo "flakeinit: agrega paquetes y corre: nix develop"
end
