# GPU / NVIDIA driver configuration
# Enables NVIDIA drivers, CUDA, and container runtime GPU passthrough
# Disk partitioning is handled by disko (disk-config.nix)

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

  # nvidia container toolkit — lets k3s pods use the GPU
  hardware.nvidia-container-toolkit.enable = true;

  # Boot — UEFI via GRUB (EC2 GPU instances support UEFI)
  boot = {
    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true; # EC2 doesn't expose real EFI vars
      device = "nodev";
    };
    initrd.availableKernelModules = [
      "nvme" "xen_blkfront" "ena"
    ];
    kernelModules = [ "nvidia" "nvidia_uvm" "nvidia_modeset" ];
  };
}
