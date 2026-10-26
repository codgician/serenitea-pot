# 🌟 Paimon

> You might be only one of countless stars, but you're Paimon's whole world!

Home lab powered by NixOS, the foundation of all infrasturctures.

## GPU unlock

`hardware.gpu-unlock` targets only the modified 48GB RTX 4090 D at `0000:81:00.0`, with the explicit 4090D experimental opt-in. The module and matching firmware come from NUR; update the `nur` flake input to consume package updates instead of overriding the source in this host configuration. The other NVIDIA devices remain assigned to VFIO.

The `without-gpu-unlock` specialisation uses the same kernel and NVIDIA driver without the unlock transaction. Keep it and an older generation available for recovery. The 350W limit and `nvidia-gpu-idle-quirk` remain independent and unchanged.

Install first-time changes with `nixos-rebuild boot`, not a live driver reload, then power off and start the machine again. The unlock must run in the initrd before NVIDIA binds the GPU; it cannot be tested by loading the module over an active driver or SGLang workload.

After the cold boot, inspect `journalctl -k -b --grep=gpu_unlock`, verify that the intended PCI device completed the transaction, and check NVIDIA initialization, memory capacity and Xid errors. A successful module load alone is not proof of an unlock; compare the upstream read-only SM-rate probe and numerical/throughput checks against a baseline before relying on it.
