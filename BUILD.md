# Hello gRPC Project Build System

This directory contains multiple gRPC implementations in various programming languages. A unified build system is provided to simplify building projects across all languages.

## Master Build Script

The `build.sh` script in the root directory allows you to build one or more language implementations at once.

### Usage

```bash
./build.sh [options] [languages...]
```

### Options

- `--clean`: Clean previous build artifacts before building
- `--help`: Show help message and usage information

### Languages

If no specific languages are specified, all projects will be built. Available language options:

- `cpp`: C++ implementation
- `csharp`: C# implementation
- `dart`: Dart implementation
- `flutter`: Flutter implementation
- `go`: Go implementation
- `java`: Java implementation
- `kotlin`: Kotlin implementation
- `nodejs`: Node.js implementation
- `php`: PHP implementation
- `python`: Python implementation
- `rust`: Rust implementation
- `swift`: Swift implementation
- `ts`: TypeScript implementation

### Examples

```bash
# Build all language implementations
./build.sh

# Clean and build all language implementations
./build.sh --clean

# Build only C++, Go, and Java implementations
./build.sh cpp go java

# Clean and build only Python and Node.js implementations
./build.sh --clean python nodejs
```

## Individual Language Builds

Each language implementation directory contains its own `build.sh` script that can be run directly:

```bash
# Build a specific language implementation
cd hello-grpc-[language]
./build.sh

# Clean and build a specific language implementation
cd hello-grpc-[language]
./build.sh --clean
```

## Requirements

Different language implementations have different requirements. Please refer to the README.md file in each language directory for specific prerequisites and setup instructions.
