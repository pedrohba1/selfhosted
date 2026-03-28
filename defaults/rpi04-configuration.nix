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
    shell = pkgs.zsh;
    # Add your public SSH key here so you can log in immediately.
    openssh.authorizedKeys.keys = [ ];

    openssh.authorizedKeys.githubKeys = [
      "pedrohba1"
      "ricardo-rp"
    ];
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
}
