# selfhosted
Plug-and-play Nix configurations and automation scripts for self-hosting everyday services: storage, media streaming, backups, IT workflows, email, blogging, federated social platforms, and private game servers. It is supposed to run cleanly on NixOS with minimal setup.


# Setting up the OS with the flake

The OS setup requires this repo:

https://github.com/nvmd/nixos-raspberrypi


It contains a `flake.nix` file that allows we to build a ready image for raspberry pi zero 2 W. I edited it a bit so
it connects to regular wifi once powered, and accepts my ssh key by default. It needs pre-defined the wifi name and password, and also the public key being passed to the Pi board. 

For all the custom configs, only the `custom-user-config` should be edited to add the dependencies. Then the image can be built, flashed into the SD card and it is done. Ideally, you just use this flake to update it. Just clone this repo
that contains the flake and run:

```bash
cd /etc/nixos-raspberrypi   # or wherever you cloned it
sudo nixos-rebuild switch --flake .#rpi02-installer

```
# Running the test vm

```
nix build .#vm
export QEMU_OPTS="-nographic -serial mon:stdio"
./result/bin/run-*-vm
```
```
```


## Building the image from the flake

You can build the image from the flake and flash into an SD card like this too:

```bash


# build the image (I use sudo because it uses the caches instead of building it locally)
# NOTICE: without sudo this will take A WHILE (some hours)
~ sudo nix build .#installerImages.rpi02
# then flash it into the SD card
 ~ zstdcat nixos-installer-rpi02-uboot.img.zst | sudo dd of=/dev/sda bs=4M status=progress conv=fsync
# sync cached writes
 ~ sync

```

By the way (reminder to self), this is what I use to download the image from the server, because I have a bulkier machine for this kind of stuff:

```

scp -r pedro@100.70.108.26:/home/pedro/Desktop/git/personal/nixos-raspberrypi/result ~/Downloads/result-today 
```
```
```



## How to set it up properly
Once the image is set, is is generally better to setup everything else with the NixOS home-manager. 

## USB gadget networking

The Pi 4 image now configures the USB-C gadget interface via `systemd-networkd`, pins it to `192.168.7.2/24`, and does not block boot if the host cable is not plugged in. To reach the Pi from your laptop, create a persistent connection for the USB interface (replace `enp0s20f0u2i1` with the actual device your host sees):

```bash
nmcli con add type ethernet ifname enp0s20f0u2i1 con-name rpi-usb \
  ipv4.method manual ipv4.addresses 192.168.7.1/24 ipv6.method ignore
nmcli con up rpi-usb
```

Once that connection is active, you can SSH to `192.168.7.2` (or `rpi04.local` if `avahi` is working) and configure the machine directly.

## Secrets handling

The flake relies on `sops-nix` (see `flake.nix`) to decrypt `./secrets/secrets.yaml` at build time; there are no plaintext secrets baked into the image. The decrypted values are injected during the build and consumed via `sops.placeholder.*` in templates (for example, the `wpa_supplicant.conf` entry in `mkPiConfig`), so runtime files are generated from those values.

You still need to provide the private key that matches the public key referenced by `/var/lib/sops-nix/key.txt` (and any other required credentials) when you build the flake, so SOPS can decrypt `secrets.yaml` before generating the installers.

