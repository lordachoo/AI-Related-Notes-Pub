# Makefile for dgx-spark-stress

# Compiler and flags
NVCC := nvcc
CFLAGS := -O3 -std=c++11
LIBS := -lnvidia-ml

# Target executable
TARGET := dgx-spark-stress

# Source file
SRC := dgx-spark-stress.cu

# Default architecture (Blackwell GB10)
ARCH := sm_90

# Detect architecture if nvidia-smi is available
ifneq ($(shell which nvidia-smi 2>/dev/null),)
    GPU_ARCH := $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1 | tr -d '.')
    ifneq ($(GPU_ARCH),)
        ARCH := sm_$(GPU_ARCH)
    endif
endif

# Build targets
.PHONY: all clean install help arch-ampere arch-ada arch-hopper arch-blackwell

all: $(TARGET)

$(TARGET): $(SRC)
	@echo "Building $(TARGET) for architecture $(ARCH)..."
	$(NVCC) $(CFLAGS) -arch=$(ARCH) $(SRC) $(LIBS) -o $(TARGET)
	@echo "Build complete: $(TARGET)"

# Architecture-specific builds
arch-ampere:
	@echo "Building for Ampere (A100, A30, A40, RTX 30xx)..."
	$(NVCC) $(CFLAGS) -arch=sm_80 $(SRC) $(LIBS) -o $(TARGET)

arch-ada:
	@echo "Building for Ada Lovelace (RTX 40xx, L40)..."
	$(NVCC) $(CFLAGS) -arch=sm_89 $(SRC) $(LIBS) -o $(TARGET)

arch-hopper:
	@echo "Building for Hopper (H100, H200)..."
	$(NVCC) $(CFLAGS) -arch=sm_90 $(SRC) $(LIBS) -o $(TARGET)

arch-blackwell:
	@echo "Building for Blackwell (GB10, GB200)..."
	$(NVCC) $(CFLAGS) -arch=sm_90 $(SRC) $(LIBS) -o $(TARGET)

# Install to /usr/local/bin (requires sudo)
install: $(TARGET)
	@echo "Installing $(TARGET) to /usr/local/bin..."
	@sudo cp $(TARGET) /usr/local/bin/
	@sudo chmod 755 /usr/local/bin/$(TARGET)
	@echo "Installation complete. Run with: $(TARGET)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(TARGET)
	@echo "Clean complete."

# Help target
help:
	@echo "dgx-spark-stress Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make                  Build for detected GPU architecture (current: $(ARCH))"
	@echo "  make arch-ampere      Build for NVIDIA Ampere (sm_80)"
	@echo "  make arch-ada         Build for NVIDIA Ada Lovelace (sm_89)"
	@echo "  make arch-hopper      Build for NVIDIA Hopper (sm_90)"
	@echo "  make arch-blackwell   Build for NVIDIA Blackwell (sm_90)"
	@echo "  make install          Install to /usr/local/bin (requires sudo)"
	@echo "  make clean            Remove build artifacts"
	@echo "  make help             Show this help message"
	@echo ""
	@echo "Override architecture:"
	@echo "  make ARCH=sm_75       Build for specific compute capability"
	@echo ""
	@echo "Example usage after build:"
	@echo "  ./$(TARGET) --precision int8 --streams 18 --unroll 3000"
