{
  description = "RPi images (Zero 2 W + Pi 4) + VM test, built on nvmd/nixos-raspberrypi";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "nix-community.cachix.org-1:mB5DZwH0U3VQVwKP1HjqCO+LwCp4WMSlyuCDDRQoxDA="
    ];
  };

  outputs =
    { self
    , nixpkgs
    , nixos-raspberrypi
    , ...
    }@inputs:
    let
      rpiLib = nixos-raspberrypi.lib;

      mkMyRpiInstaller =
        modules:
        rpiLib.nixosInstaller {
          specialArgs = inputs // {
            inherit nixos-raspberrypi;
          };

          modules = [
            nixos-raspberrypi.inputs.nixos-images.nixosModules.sdimage-installer

            (
              { config
              , lib
              , modulesPath
              , ...
              }:
              {
                disabledModules = [
                  (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
                ];

                image.baseName =
                  let
                    cfg = config.boot.loader.raspberryPi;
                  in
                  lib.mkOverride 40 "my-nixos-rpi${cfg.variant}-${cfg.bootloader}";
              }
            )
          ]
          ++ modules;
        };

      # Common bits that work on Pi + VM
      mkCommonConfig =
        hostName:
        { pkgs, lib, ... }:
        {
          networking.hostName = hostName;

          services.openssh = {
            enable = true;
            openFirewall = true;
          };

          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [
              "wheel"
              "video"
            ];
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII77IJMCjkt3Z5654YSo5QvKm3so7LwbAk8V0Ry2J7WN pedro@nixos"
            ];
          };

          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII77IJMCjkt3Z5654YSo5QvKm3so7LwbAk8V0Ry2J7WN pedro@nixos"
          ];

          environment.systemPackages = with pkgs; [
            tree
            vim
          ];

          services.avahi = {
            enable = true;
            nssmdns4 = true;
          };

          nix.settings = {
            substituters = lib.mkAfter [
              "https://nixos-raspberrypi.cachix.org"
              "https://nix-community.cachix.org"
            ];

            trusted-public-keys = lib.mkAfter [
              "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
              "nix-community.cachix.org-1:mB5DZwH0U3VQVwKP1HjqCO+LwCp4WMSlyuCDDRQoxDA="
            ];
          };

          system.stateVersion = "25.05";
        };

      # Pi-only bits (don’t reuse in VM)
      mkPiConfig =
        { pkgs, lib, ... }:
        {
          networking.networkmanager.enable = lib.mkForce false;

          networking.wireless = {
            enable = lib.mkForce true;
            iwd.enable = lib.mkForce false;
            userControlled.enable = true;

            # WARNING: don't keep PSKs in a public repo.
            networks."BusinessEfun2025-IoT".psk = "K4GtGYH$Kt";
          };

          services.udev.packages = [ pkgs.raspberrypi-udev-rules ];
        };
    in
    {
      nixosConfigurations = {
        rpi02-installer = mkMyRpiInstaller [
          (
            { ... }:
            {
              imports = with nixos-raspberrypi.nixosModules; [
                raspberry-pi-02.base
                usb-gadget-ethernet
              ];
            }
          )
          (mkCommonConfig "rpi02")
          mkPiConfig
        ];

        rpi04-installer = mkMyRpiInstaller [
          (
            { ... }:
            {
              imports = with nixos-raspberrypi.nixosModules; [
                raspberry-pi-4.base
              ];
            }
          )
          (mkCommonConfig "rpi04")
          mkPiConfig
        ];

        # VM test config (tests services/users/sshd/avahi/packages)
        vm-test = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (mkCommonConfig "vm-test")

            (
              { lib, ... }:
              {
                networking.useDHCP = lib.mkDefault true;
                services.qemuGuest.enable = true;

                # VM-only: auto-login on the serial/tty console
                services.getty.autologinUser = "root";
              }
            )
          ];
        };
      };

      installerImages = {
        rpi02 = self.nixosConfigurations.rpi02-installer.config.system.build.sdImage;
        rpi04 = self.nixosConfigurations.rpi04-installer.config.system.build.sdImage;
      };

      packages.aarch64-linux = {
        rpi02-image = self.nixosConfigurations.rpi02-installer.config.system.build.sdImage;
        rpi04-image = self.nixosConfigurations.rpi04-installer.config.system.build.sdImage;
      };

      # Convenience: build/run VM on x86_64
      packages.x86_64-linux = {
        vm = self.nixosConfigurations.vm-test.config.system.build.vm;
      };
    };
}
