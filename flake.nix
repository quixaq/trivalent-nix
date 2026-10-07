# SPDX-FileCopyrightText: 2026 Quixaq
# SPDX-License-Identifier: GPL-3.0-or-later

{
  description = "Trivalent";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    {
      packages = {
        x86_64-linux = {
          trivalent = self.lib.mkTrivalent nixpkgs.legacyPackages.x86_64-linux "x86_64";
          default = self.packages.x86_64-linux.trivalent;
        };
        aarch64-linux = {
          trivalent = self.lib.mkTrivalent nixpkgs.legacyPackages.aarch64-linux "aarch64";
          default = self.packages.aarch64-linux.trivalent;
        };
      };
      lib.mkTrivalent =
        pkgs: arch:
        let
          trivalentUnwrapped = pkgs.stdenv.mkDerivation {
            pname = "trivalent";
            version = "155.0.8059.39"; # target-ver

            src = pkgs.fetchurl {
              url =
                if arch == "x86_64" then
                  "https://repo.secureblue.dev/Packages/trivalent-155.0.8059.39-447833.x86_64.rpm" # target-x86_64-dl
                else
                  "https://repo.secureblue.dev/Packages/trivalent-155.0.8059.39-447839.aarch64.rpm"; # target-aarch64-dl
              hash =
                if arch == "x86_64" then
                  "sha256-gc2rM2YyVrDdaHUPhfOftjM7AO4J41HnmuCoMKe1WDo=" # target-x86_64-hash
                else
                  "sha256-vysrpql/kJGLIn3n0U/wCEpOdbkhFb5lIvwxfmwYGKE="; # target-aarch64-hash

            };

            nativeBuildInputs = [
              pkgs.rpm
              pkgs.cpio
              pkgs.patchelf
              pkgs.makeWrapper
            ];

            unpackPhase = "rpm2cpio $src | cpio -idmv";
            installPhase = ''
              mkdir -p $out
              cp -r usr/* $out/

              rm $out/bin/trivalent
              ln -s $out/lib64/trivalent/trivalent.sh $out/bin/trivalent-unwrapped

              substituteInPlace $out/bin/trivalent-unwrapped \
                --replace-quiet "id" "${pkgs.coreutils}/bin/id" \
                --replace-quiet "uname" "${pkgs.coreutils}/bin/uname" \
                --replace-quiet "readlink" "${pkgs.coreutils}/bin/readlink" \
                --replace-quiet "mkdir" "${pkgs.coreutils}/bin/mkdir" \
                --replace-quiet "touch" "${pkgs.coreutils}/bin/touch" \
                --replace-quiet "cat" "${pkgs.coreutils}/bin/cat" \
                --replace-quiet "bwrap" "${pkgs.bubblewrap}/bin/bwrap"
            '';

            postFixup = ''
              patchelf --set-interpreter /lib/ld-linux-${if arch == "x86_64" then "x86-64" else arch}.so.2 \
                $out/lib/trivalent/trivalent || true
            '';
          };
        in
        pkgs.buildFHSEnv {
          name = "trivalent";
          targetPkgs =
            pkgs: with pkgs; [
              glib.out
              gtk3
              pango.out
              atk
              cairo
              libx11
              libxcomposite
              libxdamage
              libxext
              libxfixes
              libxrandr
              libxkbcommon
              libxcb
              libgbm
              mesa
              alsa-lib
              pipewire
              nss
              nspr
              dbus.lib
              expat
              libffi
              cups.lib
              libgcc
              udev
              libcanberra-gtk3
              bubblewrap
              libGL
            ];
          runScript = "${trivalentUnwrapped}/lib/trivalent/trivalent";
          extraInstallCommands = ''
            mkdir -p $out/share/applications
            cp -r ${trivalentUnwrapped}/share $out/

            substituteInPlace $out/share/applications/trivalent.desktop \
              --replace "/usr/bin/trivalent" "$out/bin/trivalent"
          '';
        };
      nixosModules.default = { pkgs, ... }: {
        environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
      };
    };
}
