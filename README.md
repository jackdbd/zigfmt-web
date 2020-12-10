# zigfmt-web

Write zig code in a textarea, format it with WebAssembly.

In order to compile the .wasm module, you will need zig `0.7.0`.

```sh
# debug build 1.3MB
zig build-lib -target wasm32-freestanding-musl src/fmt.zig

# release small 228KB
zig build-lib -target wasm32-freestanding-musl -O ReleaseSmall src/fmt.zig
# release fast 319KB
zig build-lib -target wasm32-freestanding-musl -O ReleaseFast src/fmt.zig
# release safe 386KN
zig build-lib -target wasm32-freestanding-musl -O ReleaseSafe src/fmt.zig
```
