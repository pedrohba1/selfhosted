{
  description =
    "RPi Zero 2 W image with Wi-Fi + SSH, built on nvmd/nixos-raspberrypi";

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

  outputs = { self, nixpkgs, nixos-raspberrypi, ... }@inputs:
    let
      lib = nixpkgs.lib;
      rpiLib = nixos-raspberrypi.lib;

      mkMyRpiInstaller = modules:
        rpiLib.nixosInstaller {
          specialArgs = inputs // { inherit nixos-raspberrypi; };

          modules = [
            nixos-raspberrypi.inputs.nixos-images.nixosModules.sdimage-installer

            ({ config, lib, modulesPath, ... }: {
              disabledModules = [
                (modulesPath
                  + "/installer/sd-card/sd-image-aarch64-installer.nix")
              ];

              image.baseName =
                let cfg = config.boot.loader.raspberryPi;
                in
                lib.mkOverride 40
                  "my-nixos-rpi${cfg.variant}-${cfg.bootloader}";
            })
          ] ++ modules;
        };

      # ---- YOUR CONFIG (applies to installer + final system) ----
      myBaseConfig = { pkgs, lib, ... }: {

        networking.hostName = "rpi02";

        networking.networkmanager.enable = lib.mkForce false;
        networking.wireless = {
          enable = lib.mkForce true;
          iwd.enable = lib.mkForce false;
          userControlled.enable = true;

          networks."BusinessEfun2025-IoT".psk = "K4GtGYH$Kt";
        };

        # SSH daemon (final system)
        services.openssh = {
          enable = true;
          openFirewall = true;
        };

        users.users.nixos = {
          isNormalUser = true;
          extraGroups = [ "wheel" "video" ];
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII77IJMCjkt3Z5654YSo5QvKm3so7LwbAk8V0Ry2J7WN pedro@nixos"
          ];
        };

        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII77IJMCjkt3Z5654YSo5QvKm3so7LwbAk8V0Ry2J7WN pedro@nixos"
        ];

        services.udev.packages = [ pkgs.raspberrypi-udev-rules ];

        environment.systemPackages = with pkgs; [ tree vim ];

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

    in
    {

      nixosConfigurations = {
        rpi02-installer = mkMyRpiInstaller [
          ({ ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-02.base
              usb-gadget-ethernet
            ];
          })

          myBaseConfig
        ];
      };

      installerImages = {
        rpi02 =
          self.nixosConfigurations.rpi02-installer.config.system.build.sdImage;
      };

      packages.aarch64-linux.rpi02-image =
        self.nixosConfigurations.rpi02-installer.config.system.build.sdImage;
    };
}


