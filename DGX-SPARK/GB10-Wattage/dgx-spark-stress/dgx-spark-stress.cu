// sustained_power_test.cu
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <nvml.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define CHECK_NVML(call) { \
    nvmlReturn_t r = call; \
    if (r != NVML_SUCCESS) { \
        fprintf(stderr, "NVML error: %s\n", nvmlErrorString(r)); \
        exit(1); \
    } \
}

__global__ void fp32_stress(float *data, long long iters, int unroll_factor) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    float a = data[idx];
    float b = 1.0001f;
    
    for(long long i = 0; i < iters; i++) {
        for(int j = 0; j < unroll_factor; j++) {
            a = a * b + b;
            a = a * b + b;
            a = a * b + b;
            a = a * b + b;
        }
    }
    data[idx] = a;
}

__global__ void fp64_stress(double *data, long long iters, int unroll_factor) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    double a = data[idx];
    double b = 1.0001;
    
    for(long long i = 0; i < iters; i++) {
        for(int j = 0; j < unroll_factor; j++) {
            a = a * b + b;
            a = a * b + b;
        }
    }
    data[idx] = a;
}

__global__ void fp16_stress(__half *data, long long iters, int unroll_factor) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    __half a = data[idx];
    __half b = __float2half(1.0001f);
    
    for(long long i = 0; i < iters; i++) {
        for(int j = 0; j < unroll_factor; j++) {
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
            a = __hadd(__hmul(a, b), b);
        }
    }
    data[idx] = a;
}

// FP16 tensor core matrix multiply (high power!)
__global__ void fp16_tensor_matmul(__half *A, __half *B, float *C, int N, int iters) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (row >= N || col >= N) return;
    
    for(int iter = 0; iter < iters; iter++) {
        float sum = 0.0f;
        #pragma unroll 16
        for(int k = 0; k < N; k++) {
            sum += __half2float(A[row * N + k]) * __half2float(B[k * N + col]);
        }
        C[row * N + col] = sum;
    }
}

// INT8 stress (uses INT cores)
__global__ void int8_stress(char *data, long long iters, int unroll_factor) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    char a = data[idx];
    
    for(long long i = 0; i < iters; i++) {
        for(int j = 0; j < unroll_factor; j++) {
            a = a * 3 + 7;
            a = a * 3 + 7;
            a = a * 3 + 7;
            a = a * 3 + 7;
            a = a * 3 + 7;
            a = a * 3 + 7;
            a = a * 3 + 7;
            a = a * 3 + 7;
        }
    }
    data[idx] = a;
}

void print_usage(const char *prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  --mem-pct <percent>      Percentage of GPU memory to use (default: 80)\n");
    printf("  --duration <seconds>     Test duration in seconds (default: 60)\n");
    printf("  --iters <count>          Inner loop iterations (default: 100000)\n");
    printf("  --unroll <factor>        Unroll factor for operations (default: 100)\n");
    printf("  --block-size <size>      CUDA block size (default: 256)\n");
    printf("  --precision <type>       fp32, fp64, fp16, int8, or tensor (default: fp32)\n");
    printf("  --streams <count>        Number of concurrent streams (default: 1)\n");
    printf("  --matrix-size <N>        Matrix size for tensor mode (default: 4096)\n");
    printf("  --help                   Show this help\n");
}

int main(int argc, char **argv) {
    int mem_percent = 80;
    int duration = 60;
    long long iters = 100000LL;
    int unroll_factor = 100;
    int block_size = 256;
    int num_streams = 1;
    int matrix_size = 4096;
    const char *precision = "fp32";
    
    for(int i = 1; i < argc; i++) {
        if(strcmp(argv[i], "--mem-pct") == 0 && i+1 < argc) {
            mem_percent = atoi(argv[++i]);
        } else if(strcmp(argv[i], "--duration") == 0 && i+1 < argc) {
            duration = atoi(argv[++i]);
        } else if(strcmp(argv[i], "--iters") == 0 && i+1 < argc) {
            iters = atoll(argv[++i]);
        } else if(strcmp(argv[i], "--unroll") == 0 && i+1 < argc) {
            unroll_factor = atoi(argv[++i]);
        } else if(strcmp(argv[i], "--block-size") == 0 && i+1 < argc) {
            block_size = atoi(argv[++i]);
        } else if(strcmp(argv[i], "--precision") == 0 && i+1 < argc) {
            precision = argv[++i];
        } else if(strcmp(argv[i], "--streams") == 0 && i+1 < argc) {
            num_streams = atoi(argv[++i]);
        } else if(strcmp(argv[i], "--matrix-size") == 0 && i+1 < argc) {
            matrix_size = atoi(argv[++i]);
        } else if(strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        }
    }
    
    CHECK_NVML(nvmlInit_v2());
    nvmlDevice_t device;
    CHECK_NVML(nvmlDeviceGetHandleByIndex(0, &device));
    
    char name[64];
    CHECK_NVML(nvmlDeviceGetName(device, name, sizeof(name)));
    printf("GPU: %s\n", name);
    
    size_t freeMem, totalMem;
    cudaMemGetInfo(&freeMem, &totalMem);
    printf("GPU Memory: %.2f GB total, %.2f GB free\n", 
           totalMem / 1024.0 / 1024.0 / 1024.0,
           freeMem / 1024.0 / 1024.0 / 1024.0);
    
    printf("\nTest Configuration:\n");
    printf("  Precision: %s\n", precision);
    printf("  Memory usage: %d%%\n", mem_percent);
    printf("  Duration: %d seconds\n", duration);
    printf("  Iterations: %lld\n", iters);
    printf("  Unroll factor: %d\n", unroll_factor);
    printf("  Block size: %d\n", block_size);
    printf("  Streams: %d\n", num_streams);
    
    void **d_data = (void**)malloc(num_streams * sizeof(void*));
    void **d_data2 = NULL;
    void **d_data3 = NULL;
    cudaStream_t *streams = (cudaStream_t*)malloc(num_streams * sizeof(cudaStream_t));
    
    size_t elem_size;
    if(strcmp(precision, "fp64") == 0) elem_size = sizeof(double);
    else if(strcmp(precision, "fp16") == 0) elem_size = sizeof(__half);
    else if(strcmp(precision, "int8") == 0) elem_size = sizeof(char);
    else if(strcmp(precision, "tensor") == 0) elem_size = sizeof(__half);
    else elem_size = sizeof(float);
    
    if(strcmp(precision, "tensor") == 0) {
        // Allocate matrices for tensor core operations
        d_data2 = (void**)malloc(num_streams * sizeof(void*));
        d_data3 = (void**)malloc(num_streams * sizeof(void*));
        
        size_t matrix_bytes = (size_t)matrix_size * matrix_size * sizeof(__half);
        size_t output_bytes = (size_t)matrix_size * matrix_size * sizeof(float);
        
        printf("\nAllocating %d matrices of %dx%d (%.2f GB total)\n", 
               num_streams * 3, matrix_size, matrix_size,
               (matrix_bytes * 2 + output_bytes) * num_streams / 1024.0 / 1024.0 / 1024.0);
        
        for(int s = 0; s < num_streams; s++) {
            cudaMalloc(&d_data[s], matrix_bytes);   // A
            cudaMalloc(&d_data2[s], matrix_bytes);  // B
            cudaMalloc(&d_data3[s], output_bytes);  // C
            cudaMemset(d_data[s], 1, matrix_bytes);
            cudaMemset(d_data2[s], 1, matrix_bytes);
            cudaStreamCreate(&streams[s]);
        }
    } else {
        size_t bytes_per_stream = (freeMem * mem_percent / 100) / num_streams;
        size_t N = bytes_per_stream / elem_size;
        
        printf("\nAllocating %.2f GB per stream (%.2f GB total)\n", 
               bytes_per_stream / 1024.0 / 1024.0 / 1024.0,
               (bytes_per_stream * num_streams) / 1024.0 / 1024.0 / 1024.0);
        
        for(int s = 0; s < num_streams; s++) {
            cudaMalloc(&d_data[s], N * elem_size);
            cudaMemset(d_data[s], 1, N * elem_size);
            cudaStreamCreate(&streams[s]);
        }
    }
    
    printf("\nLaunching %s stress test on %d stream(s)...\n", precision, num_streams);
    printf("Monitor with: watch -n 0.5 nvidia-smi\n\n");
    
    if(strcmp(precision, "tensor") == 0) {
        dim3 block(16, 16);
        dim3 grid((matrix_size + 15) / 16, (matrix_size + 15) / 16);
        
        for(int s = 0; s < num_streams; s++) {
            fp16_tensor_matmul<<<grid, block, 0, streams[s]>>>(
                (__half*)d_data[s], (__half*)d_data2[s], (float*)d_data3[s], 
                matrix_size, iters);
        }
    } else {
        size_t bytes_per_stream = (freeMem * mem_percent / 100) / num_streams;
        size_t N = bytes_per_stream / elem_size;
        int numBlocks = (N + block_size - 1) / block_size;
        
        for(int s = 0; s < num_streams; s++) {
            if(strcmp(precision, "fp64") == 0) {
                fp64_stress<<<numBlocks, block_size, 0, streams[s]>>>((double*)d_data[s], iters, unroll_factor);
            } else if(strcmp(precision, "fp16") == 0) {
                fp16_stress<<<numBlocks, block_size, 0, streams[s]>>>((__half*)d_data[s], iters, unroll_factor);
            } else if(strcmp(precision, "int8") == 0) {
                int8_stress<<<numBlocks, block_size, 0, streams[s]>>>((char*)d_data[s], iters, unroll_factor);
            } else {
                fp32_stress<<<numBlocks, block_size, 0, streams[s]>>>((float*)d_data[s], iters, unroll_factor);
            }
        }
    }
    
    float max_power = 0.0f;
    for(int i = 0; i < duration; i++) {
        unsigned int power;
        nvmlReturn_t r = nvmlDeviceGetPowerUsage(device, &power);
        if (r == NVML_SUCCESS) {
            float power_w = power / 1000.0f;
            if(power_w > max_power) max_power = power_w;
            printf("Sample %d - Power: %.2f W (max: %.2f W)\n", i, power_w, max_power);
        }
        cudaStreamQuery(streams[0]);
        sleep(1);
    }
    
    printf("\nWaiting for kernels to finish...\n");
    cudaDeviceSynchronize();
    
    printf("\n=================================\n");
    printf("MAX POWER OBSERVED: %.2f W\n", max_power);
    printf("=================================\n");
    
    for(int s = 0; s < num_streams; s++) {
        cudaFree(d_data[s]);
        if(d_data2) cudaFree(d_data2[s]);
        if(d_data3) cudaFree(d_data3[s]);
        cudaStreamDestroy(streams[s]);
    }
    free(d_data);
    if(d_data2) free(d_data2);
    if(d_data3) free(d_data3);
    free(streams);
    nvmlShutdown();
    
    return 0;
}
