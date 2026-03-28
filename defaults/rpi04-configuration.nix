{ config, pkgs, ... }:
{
  # Start customizing this configuration once the image boots.
  system.stateVersion = "25.05";
  networking.hostName = "rpi04";

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
    ];
    # Add your public SSH key here so you can log in immediately.
    openssh.authorizedKeys.keys = [ ];

    openssh.authorizedKeys.githubKeys = [
      "pedrohba1"
      "ricardo-rp"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    tree
  ];

  # Uncomment or add modules and services you need below:
  services.openssh.enable = true;
  services.networkmanager.enable = true;
  # hardware.pulseaudio.enable = true;
}
