# dgx-spark-stress

A CUDA-based GPU power stress testing tool designed to measure maximum power consumption on NVIDIA GPUs, with specific optimizations for Blackwell architecture (GB10) systems like the DGX SPARK.

## Overview

`dgx-spark-stress` allows you to saturate different GPU execution units (FP32, FP64, FP16, INT8, and Tensor Cores) to determine the actual power limits of your GPU under various workloads. This tool is particularly useful for:

- Verifying GPU power delivery capabilities
- Testing thermal solutions under maximum load
- Identifying which workload types draw the most power
- Benchmarking power consumption across different precision modes

## Key Findings (DGX SPARK / GB10)

Testing on NVIDIA GB10 revealed:

- **FP32 workloads**: Peak ~66-72W
- **FP64 workloads**: Peak ~65-68W  
- **INT8 workloads**: Peak **~105W** (highest power draw)
- **Optimal configuration**: 18 streams, unroll factor 3000, block size 256-512

INT8 operations utilize dedicated integer execution units that draw significantly more power than floating-point units on this architecture.

## Building

Requires NVIDIA CUDA Toolkit (tested with CUDA 12.0+) and NVML library.

```bash
nvcc -O3 -arch=sm_90 sustained_power_test.cu -lnvidia-ml -o dgx-spark-stress
```

For other GPU architectures, adjust the `-arch` flag:
- Ampere (A100): `-arch=sm_80`
- Ada Lovelace (RTX 40xx): `-arch=sm_89`
- Hopper (H100): `-arch=sm_90`

## Usage

```bash
./dgx-spark-stress [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--precision <type>` | Workload type: fp32, fp64, fp16, int8, or tensor | fp32 |
| `--streams <count>` | Number of concurrent CUDA streams | 1 |
| `--mem-pct <percent>` | Percentage of GPU memory to allocate | 80 |
| `--unroll <factor>` | Operation unroll factor (higher = more compute) | 100 |
| `--block-size <size>` | CUDA block size (threads per block) | 256 |
| `--iters <count>` | Inner loop iteration count | 100000 |
| `--duration <seconds>` | Test duration for power sampling | 60 |
| `--matrix-size <N>` | Matrix dimension for tensor mode | 4096 |
| `--help` | Display help message | - |

## Examples

### Basic FP32 Test
```bash
./dgx-spark-stress --precision fp32 --duration 120
```

### Maximum INT8 Power Draw (Recommended for GB10)
```bash
./dgx-spark-stress --precision int8 --streams 18 --unroll 3000 --mem-pct 95 --duration 120
```

### High Memory Pressure Test
```bash
./dgx-spark-stress --precision int8 --streams 32 --mem-pct 98 --block-size 1024
```

### Tensor Core Stress Test
```bash
./dgx-spark-stress --precision tensor --streams 16 --matrix-size 8192 --iters 10000
```

### FP16 Compute Test
```bash
./dgx-spark-stress --precision fp16 --streams 16 --unroll 2000 --mem-pct 95
```

## Sample Output

```
GPU: NVIDIA GB10
GPU Memory: 119.70 GB total, 106.02 GB free

Test Configuration:
  Precision: int8
  Memory usage: 80%
  Duration: 120 seconds
  Iterations: 10000
  Unroll factor: 3000
  Block size: 256
  Streams: 18

Allocating 4.71 GB per stream (84.81 GB total)

Launching int8 stress test on 18 stream(s)...
Monitor with: watch -n 0.5 nvidia-smi

Sample 0 - Power: 19.00 W (max: 19.00 W)
Sample 1 - Power: 69.53 W (max: 69.53 W)
Sample 2 - Power: 103.00 W (max: 103.00 W)
Sample 3 - Power: 103.22 W (max: 103.22 W)
Sample 4 - Power: 103.79 W (max: 103.79 W)
Sample 5 - Power: 103.57 W (max: 103.79 W)
...
Sample 11 - Power: 104.23 W (max: 104.70 W)

=================================
MAX POWER OBSERVED: 104.70 W
=================================
```

## Monitoring Power in Real-Time

While `dgx-spark-stress` is running, monitor GPU stats in another terminal:

```bash
# Simple power monitoring
watch -n 0.5 nvidia-smi

# Detailed metrics
nvidia-smi dmon -s pucvmet

# Continuous logging to file
nvidia-smi dmon -s pucvmet -d 1 > power_log.txt

# Temperature and clock monitoring
nvidia-smi --query-gpu=temperature.gpu,temperature.memory,power.draw,clocks.current.graphics --format=csv -l 1
```

## Tuning for Maximum Power

The parameters that most directly impact power draw (in order):

1. **`--unroll <factor>`** - Increases operations per loop. Try values 1000-5000 for maximum compute density.
2. **`--streams <count>`** - More streams saturate more SMs. Optimal value varies by GPU (typically 16-32).
3. **`--mem-pct <percent>`** - Higher memory usage increases SM occupancy. Try 95-98% for maximum load.
4. **`--block-size <size>`** - Affects occupancy. Try 512 or 1024 if 256 doesn't maximize power.
5. **`--precision <type>`** - Different execution units draw different power. INT8 often highest on modern GPUs.

## Architecture-Specific Notes

### Blackwell (GB10)
- INT8 operations draw significantly more power than FP32/FP64
- Peak observed power: ~105W with INT8 workloads
- Optimal: 18 streams, unroll 3000, block size 256-512

### General Guidelines
- For inference accelerators, try INT8 and FP16 first
- For compute GPUs (A100, H100), try FP64 and tensor modes
- Monitor temperature - if clocks drop, you're thermally limited, not power limited

## Troubleshooting

### Power readings show "Not Supported"
Some NVML power management queries aren't supported on all GPUs. The tool will skip unsupported queries and continue.

### GPU not reaching expected power levels
- Ensure the workload is running (should take 60+ seconds)
- Try different precision modes - some execution units may be power-limited independently
- Check thermal throttling with `nvidia-smi` - high temps cause power reduction
- Verify persistence mode: `sudo nvidia-smi -pm 1`

### Out of memory errors
- Reduce `--mem-pct` (try 70 or 60)
- Reduce `--streams` count
- For tensor mode, reduce `--matrix-size`

## Understanding the Results

The tool reports power consumption every second and tracks the maximum observed value. Key things to note:

- **Startup power (~20-70W)**: Normal during kernel launch and warmup
- **Sustained power (100-105W)**: Actual sustained maximum under load
- **Power drops after ~30 seconds**: May indicate thermal throttling or workload completion
- **Consistent plateau**: Indicates you've hit the power limit (good!)

If power drops significantly during the test, the workload may be completing too quickly. Increase `--iters` to extend runtime.

## License

This tool is provided as-is for GPU testing and benchmarking purposes.

## Contributing

Contributions welcome! Particularly interested in:
- Results from other GPU architectures
- Additional workload types (mixed precision, etc.)
- Optimization for specific use cases

## Credits

Developed by Andrew Nelson for characterizing power delivery on DGX SPARK systems with GB10 GPUs. 