{
  description = "RPi images (Zero 2 W + Pi 4) + VM test, built on nvmd/nixos-raspberrypi";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    {
      self,
      nixpkgs,
      nixos-raspberrypi,
      ...
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
              {
                config,
                lib,
                modulesPath,
                ...
              }:
              {
                disabledModules = [
                  (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
                ];

                image.baseName = lib.mkOverride 40 "my-${config.networking.hostName}";
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

          imports = [
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
          ];

          sops = {
            defaultSopsFile = ./secrets/secrets.yaml;
            age.keyFile = "/var/lib/sops-nix/key.txt";
          };

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

          environment.etc = lib.mkMerge [
            (lib.mkIf (hostName == "rpi04") {
              "configuration.nix".source = ./defaults/rpi04-configuration.nix;
            })
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
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          boot.loader.grub.enable = false;
          boot.loader.generic-extlinux-compatible.enable = true;

          networking.networkmanager.enable = lib.mkForce false;
          networking.wireless.enable = lib.mkForce true;
          networking.wireless.iwd.enable = lib.mkForce false;
          networking.wireless.userControlled.enable = lib.mkForce false;

          networking.interfaces.wlan0.useDHCP = true;

          networking.wireless.networks."ROMARTINS".psk = "Woodtree57";
          networking.wireless.networks."Santa Cruz".psk = "Woodtree57";

          services.udev.packages = [ pkgs.raspberrypi-udev-rules ];

          networking.useNetworkd = true;
          systemd.network.enable = true;

          systemd.network.networks."usb-gadget" = {
            matchConfig = {
              Driver = "usb0";
            };

            networkConfig = {
              Address = "192.168.7.2/24";
              ConfigureWithoutCarrier = true;
              DHCPServer = true;
            };

            dhcpServerConfig = {
              PoolOffset = 10;
              PoolSize = 20;
              EmitDNS = true;
            };

            linkConfig.RequiredForOnline = "no";
          };
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
                usb-gadget-ethernet
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
