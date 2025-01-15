{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {pkgs, ...}: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            zig
            zls

            ghostscript
            glib
            libbfd
            librsvg
            libspectre
            lzo
            pixman
            pkg-config
            poppler
            python3
            xorg.libX11
            xorg.libXext
            xorg.libXrender
            xorg.libxcb
            xorg.xorgproto
          ];
        };
      };
    };
}
