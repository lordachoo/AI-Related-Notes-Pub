# Combining Split GGUF Files on ARM-based DGX SPARK

## Problem
Needed to merge split GGUF model files on an ARM-based DGX SPARK system using `llama-gguf-split`.

## Solution

### 1. Clone llama.cpp repository
```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
```

### 2. Install dependencies
```bash
sudo apt-get update
sudo apt-get install cmake libcurl4-openssl-dev
```

### 3. Build llama-gguf-split tool
```bash
# Create build directory
mkdir build
cd build

# Configure with CMake
cmake ..

# Build the gguf-split tool
cmake --build . --target llama-gguf-split
```

### 4. Use the tool to merge split files
```bash
# The binary will be located at:
./bin/llama-gguf-split

# To merge split GGUF files:
./bin/llama-gguf-split --merge <input-split-file> <output-file>

# Example:
./bin/llama-gguf-split --merge model-00001-of-00003.gguf model-combined.gguf
```

## Notes
- llama.cpp recently switched from Makefile to CMake build system
- The tool automatically finds all split parts (part1, part2, etc.) when merging
- ARM64 architecture is well-supported by llama.cpp
- Build completed successfully on DGX SPARK ARM system with GCC 13.3.0

## What is GGUF?
GGUF (GPT-Generated Unified Format) is a model format used primarily with llama.cpp for running large language models locally on consumer hardware. The format contains quantized models where weights are compressed from their original precision (float16/float32) down to lower bit representations (4-bit, 8-bit, etc.), dramatically reducing file size and memory requirements while maintaining reasonable performance.

## Common Use Cases
- Running LLMs locally without expensive GPU servers
- Used by tools like LM Studio, Ollama, and KoboldCpp
- Popular in the open-source AI community for local model inference

# Outputs / Notes

- Takes a few minutes 
- file will be in `/build/bin`

```
anelson@dgx-spark0:~/llama.cpp/build/bin$ ./llama-gguf-split 
error: bad arguments

usage: ./llama-gguf-split [options] GGUF_IN GGUF_OUT

Apply a GGUF operation on IN to OUT.
options:
  -h, --help              show this help message and exit
  --version               show version and build info
  --split                 split GGUF to multiple GGUF (enabled by default)
  --merge                 merge multiple GGUF to a single GGUF
  --split-max-tensors     max tensors in each split (default: 128)
  --split-max-size N(M|G) max size per split
  --no-tensor-first-split do not add tensors to the first split (disabled by default)
  --dry-run               only print out a split plan and exit, without writing any new files
```

- Running it :

```
anelson@dgx-spark0:~/llama.cpp/build/bin$ ./llama-gguf-split --merge ~/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00001-of-00003.gguf ~/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4.gguf
gguf_merge: /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00001-of-00003.gguf -> /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4.gguf
gguf_merge: reading metadata /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00001-of-00003.gguf done
gguf_merge: reading metadata /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00002-of-00003.gguf done
gguf_merge: reading metadata /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00003-of-00003.gguf done
gguf_merge: writing tensors /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00001-of-00003.gguf done
gguf_merge: writing tensors /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00002-of-00003.gguf done
gguf_merge: writing tensors /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4-00003-of-00003.gguf done
gguf_merge: /home/anelson/llm_models/gpt-oss-120b-mxfp4/gpt-oss-120b-mxfp4.gguf merged from 3 split with 687 tensors.
```

## COMPILE OUT 

```bash
anelson@dgx-spark0:~/llama.cpp/build$ cmake --build . --target llama-gguf-split
[  0%] Building CXX object common/CMakeFiles/build_info.dir/build-info.cpp.o
[  0%] Built target build_info
[  2%] Building C object ggml/src/CMakeFiles/ggml-base.dir/ggml.c.o
[  2%] Building CXX object ggml/src/CMakeFiles/ggml-base.dir/ggml.cpp.o
[  2%] Building C object ggml/src/CMakeFiles/ggml-base.dir/ggml-alloc.c.o
[  4%] Building CXX object ggml/src/CMakeFiles/ggml-base.dir/ggml-backend.cpp.o
[  4%] Building CXX object ggml/src/CMakeFiles/ggml-base.dir/ggml-opt.cpp.o
...
[ 89%] Built target llama
[ 89%] Building CXX object common/CMakeFiles/common.dir/arg.cpp.o
[ 89%] Building CXX object common/CMakeFiles/common.dir/chat-parser.cpp.o
[ 91%] Building CXX object common/CMakeFiles/common.dir/chat-parser-xml-toolcall.cpp.o
[ 91%] Building CXX object common/CMakeFiles/common.dir/chat.cpp.o
[ 91%] Building CXX object common/CMakeFiles/common.dir/common.cpp.o
[ 91%] Building CXX object common/CMakeFiles/common.dir/console.cpp.o
[ 93%] Building CXX object common/CMakeFiles/common.dir/download.cpp.o
[ 93%] Building CXX object common/CMakeFiles/common.dir/json-partial.cpp.o
[ 93%] Building CXX object common/CMakeFiles/common.dir/json-schema-to-grammar.cpp.o
[ 95%] Building CXX object common/CMakeFiles/common.dir/llguidance.cpp.o
[ 95%] Building CXX object common/CMakeFiles/common.dir/log.cpp.o
[ 95%] Building CXX object common/CMakeFiles/common.dir/ngram-cache.cpp.o
[ 95%] Building CXX object common/CMakeFiles/common.dir/regex-partial.cpp.o
[ 97%] Building CXX object common/CMakeFiles/common.dir/sampling.cpp.o
[ 97%] Building CXX object common/CMakeFiles/common.dir/speculative.cpp.o
[ 97%] Linking CXX static library libcommon.a
[ 97%] Built target common
[ 97%] Building CXX object tools/gguf-split/CMakeFiles/llama-gguf-split.dir/gguf-split.cpp.o
[100%] Linking CXX executable ../../bin/llama-gguf-split
[100%] Built target llama-gguf-split
```

# Importing merged file into ollama

- Create `Modelfile` and reference the merged file

```
FROM /path/to/your/merged/file/merged-filename.gguf
```

- run `ollama create ${modelName} ${PathToYour-Modelfile}`

E.g 

```
ollama create gpt-oss-120b -f ~/llm_models/gpt-oss-120b-mxfp4/Modelfile 
```
