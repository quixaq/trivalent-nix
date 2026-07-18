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
      lib.mkGlibC =
        pkgs: arch:
        pkgs.stdenv.mkDerivation {
          pname = "glibc";
          version = "2.43";

          src = pkgs.fetchurl {
            url = "https://dl.fedoraproject.org/pub/fedora/linux/updates/44/Everything/${arch}/Packages/g/glibc-2.43-7.fc44.${arch}.rpm";
            hash =
              if arch == "x86_64" then
                "sha256-JpOkT58Pdf8PjeSTR6Sk+ooopVzO39HLtQG/XgZ1WWg="
              else
                "sha256-taoQl6WeGop0PlI/0dJv+b1xnmfyoa5gMXErrTjOKAo=";
          };

          nativeBuildInputs = [
            pkgs.rpm
            pkgs.cpio
          ];

          unpackPhase = "rpm2cpio $src | cpio -idmv";
          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';
        };
      lib.mkTrivalent =
        pkgs: arch:
        let
          glibcRpm = self.lib.mkGlibC pkgs arch;
          rpathsList = [
            pkgs.glib.out
            pkgs.gtk3
            pkgs.pango.out
            pkgs.atk
            pkgs.cairo
            pkgs.libx11
            pkgs.libxcomposite
            pkgs.libxdamage
            pkgs.libxext
            pkgs.libxfixes
            pkgs.libxrandr
            pkgs.libxkbcommon
            pkgs.libxcb
            pkgs.libgbm
            pkgs.mesa
            pkgs.alsa-lib
            pkgs.pipewire
            pkgs.nss
            pkgs.nspr
            pkgs.dbus.lib
            pkgs.expat
            pkgs.libffi
            pkgs.cups.lib
            pkgs.libgcc
            pkgs.udev
            pkgs.libcanberra-gtk3
            pkgs.bubblewrap
          ];
          rpaths = pkgs.lib.concatStringsSep "/lib:" rpathsList;

          trivalentUnwrapped = pkgs.stdenv.mkDerivation {
            pname = "trivalent";
            version = "150.0.7871.128";

            src = pkgs.fetchurl {
              url =
                if arch == "x86_64" then
                  "https://repo.secureblue.dev/Packages/trivalent-150.0.7871.128-446079.x86_64.rpm"
                else
                  "https://repo.secureblue.dev/Packages/trivalent-150.0.7871.128-446081.aarch64.rpm";
              hash =
                if arch == "x86_64" then
                  "sha256-Ao7Ted8NeQNnG0gt3OCmJTpw+MSiqb5MeCCJLy+/77M="
                else
                  "sha256-veHa2MNy0DRuNeeIITKoneoMn1g+3qPz36AeyIDzc0A=";
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
                --replace "id" "${pkgs.coreutils}/bin/id" \
                --replace "uname" "${pkgs.coreutils}/bin/uname" \
                --replace "readlink" "${pkgs.coreutils}/bin/readlink" \
                --replace "mkdir" "${pkgs.coreutils}/bin/mkdir" \
                --replace "touch" "${pkgs.coreutils}/bin/touch" \
                --replace "cat" "${pkgs.coreutils}/bin/cat" \
                --replace "bwrap" "${pkgs.bubblewrap}/bin/bwrap"
            '';

            postFixup = ''
              patchelf --set-interpreter ${glibcRpm}/usr/lib64/ld-linux-${
                if arch == "x86_64" then "x86-64" else arch
              }.so.2 \
                $out/lib/trivalent/trivalent

              OLD_RPATH=$(patchelf --print-rpath "$out/lib/trivalent/trivalent" || echo "")

              RPATHS="${glibcRpm}/usr/lib64:${rpaths}/lib"

              if [ -n "$OLD_RPATH" ]; then
                NEW_RPATH="$RPATHS:$OLD_RPATH"
              else
                NEW_RPATH="$RPATHS"
              fi

              patchelf --set-rpath "$NEW_RPATH" \
                $out/lib/trivalent/trivalent
            '';
          };
        in
        pkgs.buildFHSEnv {
          name = "trivalent";
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
