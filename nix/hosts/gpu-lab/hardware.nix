# GPU / NVIDIA driver configuration
# Enables NVIDIA drivers, CUDA, and container runtime GPU passthrough
{ config, pkgs, lib, ... }:

{
  # NVIDIA drivers
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    open = false;
  };

  # Enable OpenGL for GPU compute
  hardware.graphics.enable = true;

  # NVIDIA Container Toolkit — lets k3s pods use the GPU
  hardware.nvidia-container-toolkit.enable = true;

  # Boot config
  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/vda"; # Digital Ocean typically uses virtio
    };
    initrd.availableKernelModules = [
      "virtio_pci" "virtio_scsi" "ahci" "sd_mod"
    ];
    kernelModules = [ "nvidia" "nvidia_uvm" "nvidia_modeset" ];
  };

  # Filesystem — adjust to match the actual droplet disk layout
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
}
