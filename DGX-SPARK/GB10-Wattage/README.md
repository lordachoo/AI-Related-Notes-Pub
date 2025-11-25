# GB10 Wattage Cap on DGX SPARK (?)

## Power throttled!

```bash
anelson@dgx-spark0:~/my-repos/AI-Related-Notes-Pub/DGX-SPARK-A0/GB10-Wattage$ nvidia-smi -q -d PERFORMANCE

==============NVSMI LOG==============

Timestamp                                 : Mon Nov 24 19:48:06 2025
Driver Version                            : 580.95.05
CUDA Version                              : 13.0

Attached GPUs                             : 1
GPU 0000000F:01:00.0
    Performance State                     : P0
    Clocks Event Reasons
        Idle                              : Not Active
        Applications Clocks Setting       : Not Active
        SW Power Cap                      : Not Active
        HW Slowdown                       : Not Active
            HW Thermal Slowdown           : Not Active
            HW Power Brake Slowdown       : Not Active
        Sync Boost                        : Not Active
        SW Thermal Slowdown               : Not Active
        Display Clock Setting             : Not Active
    Clocks Event Reasons Counters
        SW Power Capping                  : 50284264713 us            ### <--- Throttled for 14 hours? 50K Seconds?
        Sync Boost                        : 0 us
        SW Thermal Slowdown               : 0 us
        HW Thermal Slowdown               : 0 us
        HW Power Braking                  : 0 us
    Sparse Operation Mode                 : N/A
```

## Can you change the watt limit?

- No. 

```bash
anelson@dgx-spark0:~/my-repos/AI-Related-Notes-Pub/DGX-SPARK-A0/GB10-Wattage$ sudo nvidia-smi -pl 150
Changing power management limit is not supported in current scope for GPU: 0000000F:01:00.0.
All done.
```

## How far can we push it?

- See [DGX Spark Stress](./dgx-spark-stress/README.md)
   - I was able to get to 105W - but I could not get beyond that wall
   - `make arch-blackwell; ./dgx-spark-stress --precision int8 --streams 32 --unroll 5000 --block-size 1024 --mem-pct 98`


```bash
Mon Nov 24 20:25:50 2025       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.95.05              Driver Version: 580.95.05      CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GB10                    On  |   0000000F:01:00.0 Off |                  N/A |
| N/A   74C    P0            105W /  N/A  | Not Supported          |     96%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A          452072      C   ./dgx-spark-stress                    87012MiB |
+-----------------------------------------------------------------------------------------+
```