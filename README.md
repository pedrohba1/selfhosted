# selfhosted
Plug-and-play Nix configurations and automation scripts for self-hosting everyday services: storage, media streaming, backups, IT workflows, email, blogging, federated social platforms, and private game servers. It is supposed to run cleanly on NixOS with minimal setup.


# Setting up the OS with the flake

The OS setup requires this repo:

https://github.com/nvmd/nixos-raspberrypi


It contains a `flake.nix` file that allows we to build a ready image for raspberry pi zero 2 W. I edited it a bit so
it connects to regular wi-fi once powered, and accepts my ssh key by default. It needs pre-defined the wifi name and password, and also the public key being passed to the Pi board. 

For all the custom configs, only the `custom-user-config` should be edited to add the dependencies. Then the image can be built, flashed into the SD card and it is done. Ideally, you just use this flake to update it. Just clone this repo
that contains the flake and run:

```bash
cd /etc/nixos-raspberrypi   # or wherever you cloned it
sudo nixos-rebuild switch --flake .#rpi02-installer

```

## Building the image from the flake

You can build the image from the flake and flash into an SD card like this too:

```bash


# build the image
~ nix build .#installerImages.rpi02
# then flash it into the SD card
 ~ zstdcat nixos-installer-rpi02-uboot.img.zst | sudo dd of=/dev/sda bs=4M status=progress conv=fsync
```







