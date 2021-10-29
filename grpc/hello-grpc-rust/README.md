## grpc rust[tonic] demo

### 1 Generate & Build
```bash
export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
rustup toolchain install nightly
rustup default nightly
rustup show
```

```bash
cargo build
```

#### dev
find generated rust code(org.feuyeux.grpc.rs)

```bash
$ find . -name "*.rs"

./target/debug/build/hello-grpc-rust-b1aedb8eb000afe4/out/org.feuyeux.grpc.rs
./target/debug/build/anyhow-db0336bb83000618/out/probe.rs
./build.rs
./main.rs
./src/client.rs
./src/server.rs
```

### 2 Run
```bash
cargo run --bin proto-server
```

```bash
cargo run --bin proto-client
```

### Release(Crossing Platform Support)
```bash
# https://doc.rust-lang.org/nightly/rustc/platform-support.html
# https://doc.rust-lang.org/edition-guide/rust-2018/platform-and-target-support/musl-support-for-fully-static-binaries.html
rustup update
rustup target add x86_64-unknown-linux-musl
rustup show

# 1 error: linking with `cc` failed: exit code: 1
# clang: error: linker command failed with exit code 1 (use -v to see invocation)
# `brew install FiloSottile/musl-cross/musl-cross`
# `ln -s /usr/local/bin/x86_64-linux-musl-gcc /usr/local/bin/musl-gcc`

# 2 Error: Your CLT does not support macOS 11.2.
# `sudo rm -rf /Library/Developer/CommandLineTools`
# `sudo xcode-select --install`

# https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_12.5_beta/Command_Line_Tools_for_Xcode_12.5_beta.dmg
# https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_13/Command_Line_Tools_for_Xcode_13.dmg
# `/usr/bin/xcodebuild -version`
# xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
# `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`

# `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables`
# package-id: com.apple.pkg.CLTools_Executables
# version: 12.5.0.0.1.1611946261
# volume: /
# location: /
# install-time: 1612700387
# groups: com.apple.FindSystemFiles.pkg-group

CROSS_COMPILE=x86_64-linux-musl-gcc cargo build --release --bin proto-server --target=x86_64-unknown-linux-musl
```

### Reference
- https://github.com/hyperium/tonic