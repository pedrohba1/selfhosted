{
  description =
    "My custom Raspberry Pi images built on top of nvmd/nixos-raspberrypi";

  inputs = {
    # Upstream RPi flake you showed
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi";

    # Follow its nixpkgs so you don't get a mismatch
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, ... }@inputs:
    let
      lib = nixpkgs.lib;
      rpiLib = nixos-raspberrypi.lib;

      # Helper that does the same thing as in their flake:
      mkMyRpiInstaller = modules:
        rpiLib.nixosInstaller {
          specialArgs = inputs // { inherit nixos-raspberrypi; };
          modules =
            # reuse their sd-card installer module wiring
            [
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

      # your custom module with extra software / settings
      myBaseConfig = { config, pkgs, lib, nixos-raspberrypi, ... }: {
        # Wi-Fi example (reuse what you already had)
        networking.networkmanager.enable = lib.mkForce false;
        networking.wireless = {
          enable = lib.mkForce true;
          iwd.enable = lib.mkForce false;
          userControlled.enable = false;
          # TODO:  yes, this is my wifi password. And it shoulnd't be here
          # I'm stil figuring out how to NOT have it here.
          networks."BusinessEfun2025-IoT".psk = "K4GtGYH$Kt";
        };

        services.openssh.enable = true;

        users.users.nixos = {
          isNormalUser = true;
          extraGroups = [ "wheel" "video" ]; # sudo + camera access
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII77IJMCjkt3Z5654YSo5QvKm3so7LwbAk8V0Ry2J7WN pedro@nixos"
          ];
        };

        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII77IJMCjkt3Z5654YSo5QvKm3so7LwbAk8V0Ry2J7WN pedro@nixos"
        ];

        # THIS is where you add stuff you want in every image
        environment.systemPackages = with pkgs; [
          tree
          vim
          ffmpeg_7
          libcamera
          rpicam-apps
        ];

        services.udev.packages = [ pkgs.raspberrypi-udev-rules ];

        system.stateVersion = "25.11";
      };
    in
    {
      # Your own NixOS configs built on top of theirs
      nixosConfigurations = {
        rpi02-installer = mkMyRpiInstaller [
          # pull in their RPi Zero 2 W base modules
          ({ config, pkgs, lib, nixos-raspberrypi, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-02.base
              usb-gadget-ethernet
            ];
          })
          myBaseConfig
        ];

      };

      installerImages =
        let
          nixos = self.nixosConfigurations;
          mkImage = nixosConfig: nixosConfig.config.system.build.sdImage;
        in
        { rpi02 = mkImage nixos.rpi02-installer; };
      # Convenient image outputs
      packages = {
        aarch64-linux.rpi02-image =
          self.nixosConfigurations.rpi02-installer.config.system.build.sdImage;
      };
    };

}

