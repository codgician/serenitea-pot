"""Move idle NVIDIA GPUs out of P0 into their lowest memory clock state.

The modded RTX 4090 D 48GB VBIOS only has two performance levels, P0
(10501 MHz memory) and P8 (405 MHz). The driver raises the GPU to P0 when
work arrives but never lowers it again, even with no client attached.
Locking the memory clock to its floor and then releasing the lock moves the
GPU to P8, where it stays until work raises it again.
"""

import signal
import sys
import time

import pynvml as nv

POLL_SECONDS = 5
# Idle time in P0 before the memory clock is forced down. The driver only
# reports the GPU idle about 17s after work stops, on top of this.
IDLE_SECONDS = 15
LOCK_SECONDS = 1


def busy(handle):
    util = nv.nvmlDeviceGetUtilizationRates(handle)
    reasons = nv.nvmlDeviceGetCurrentClocksEventReasons(handle)
    idle = reasons & nv.nvmlClocksEventReasonGpuIdle
    return util.gpu > 0 or util.memory > 0 or not idle


def drop(handle, floor):
    nv.nvmlDeviceSetMemoryLockedClocks(handle, floor, floor)
    try:
        time.sleep(LOCK_SECONDS)
    finally:
        nv.nvmlDeviceResetMemoryLockedClocks(handle)


def main():
    # Raise SystemExit on stop so an active lock is always released.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    nv.nvmlInit()
    gpus = []
    for index in range(nv.nvmlDeviceGetCount()):
        handle = nv.nvmlDeviceGetHandleByIndex(index)
        floor = min(nv.nvmlDeviceGetSupportedMemoryClocks(handle))
        gpus.append({"index": index, "handle": handle, "floor": floor})

    idle_since = {}
    while True:
        now = time.monotonic()
        for gpu in gpus:
            handle, floor = gpu["handle"], gpu["floor"]
            clock = nv.nvmlDeviceGetClockInfo(handle, nv.NVML_CLOCK_MEM)
            if clock <= floor or busy(handle):
                idle_since.pop(gpu["index"], None)
                continue
            since = idle_since.setdefault(gpu["index"], now)
            if now - since >= IDLE_SECONDS:
                print(
                    f"GPU {gpu['index']}: idle at {clock} MHz for "
                    f"{IDLE_SECONDS}s, forcing memory clock to {floor} MHz",
                    flush=True,
                )
                drop(handle, floor)
                idle_since.pop(gpu["index"], None)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
