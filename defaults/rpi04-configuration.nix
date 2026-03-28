{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Start customizing this configuration once the image boots.
  networking.hostName = "rpi04";

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    git
    networkmanager
    curl
    htop
    tree
    vim
  ];

  # Uncomment or add modules and services you need below:
  services.openssh.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellInit = ''
      # The following lines were added by compinstall
      zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
      zstyle :compinstall filename "$HOME/.zshrc"

      autoload -Uz compinit
      compinit
      # End of lines added by compinstall
      # Lines configured by zsh-newuser-install
      HISTFILE=~/.histfile
      HISTSIZE=1000
      SAVEHIST=1000
      setopt beep
      bindkey -v
      # End of lines configured by zsh-newuser-install

      # PATH additions (append/prepend without clobbering)
      typeset -Ua path
      path=("$HOME/.npm-packages/bin" $path)   # prepend npm bin
      path+=("$HOME/.foundry/bin")             # append foundry

      export COLORTERM=truecolor
      export PATH="$HOME/.local/bin:$PATH"
    '';
  };

  networking.networkmanager.ensureProfiles.profiles.Romartins = {
    connection = {
      id = "ROMARTINS";
      type = "wifi";
      interface-name = "wlan0";
      autoconnect = true;
    };

    wifi = {
      mode = "infrastructure";
      ssid = "ROMARTINS";
    };

    "wifi-security" = {
      key-mgmt = "wpa-psk";
      psk = "Woodtree57";
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };

  networking.networkmanager.ensureProfiles.profiles.SantaCruz = {
    connection = {
      id = "Santa Cruz";
      type = "wifi";
      interface-name = "wlan0";
      autoconnect = true;
    };

    wifi = {
      mode = "infrastructure";
      ssid = "Santa Cruz";
    };

    "wifi-security" = {
      key-mgmt = "wpa-psk";
      psk = "Woodtree57";
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}
