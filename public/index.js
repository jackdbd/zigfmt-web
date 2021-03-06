const formatZigCode = function (source) {
  // In zig, string literals are const pointers to arrays of u8, and by convention parameters that are
  // "strings" are expected to be UTF-8 encoded slices of u8. So we need to convert source to Uint8Array.
  const textEncoder = new TextEncoder();
  const sourceArray = textEncoder.encode(source);

  // get memory from wasm
  // assume first memory locations are for return values, the rest are for params
  const return_len = 32 / 8 + 32 / 8; // u32, u32
  const source_len = sourceArray.length;
  const ptr = this._wasm_alloc(return_len + source_len);
  if (ptr === 0) {
    throw new Error("Cannot allocate WASM memory");
  }

  // copy sourceArray to wasm
  var memoryu8 = new Uint8Array(this.memory.buffer);
  for (let i = 0; i < source_len; ++i) {
    memoryu8[ptr + return_len + i] = sourceArray[i];
  }

  const succeed = this.format_export(
    ptr + return_len,
    source_len,
    ptr,
    ptr + 32 / 8
  );
  console.log("formatZigCode called wasm module?", succeed);

  // read result into Uint32Array()
  const return_slice = new Uint32Array(
    this.memory.buffer.slice(ptr, ptr + return_len)
  );
  const return_val_ptr = return_slice[0];
  const return_val_len = return_slice[1];

  // dealloc function params
  this._wasm_dealloc(ptr, return_len + source_len);

  // throw if function returned error
  if (!succeed) {
    alert("WASM Call returned error");
  }

  // get the result
  const result = new Uint8Array(
    this.memory.buffer.slice(return_val_ptr, return_val_ptr + return_val_len)
  );

  // dealloc result
  this._wasm_dealloc(return_val_ptr, return_val_len);

  // decode result
  const textDecoder = new TextDecoder();

  // return result
  return textDecoder.decode(result);
};

const btnFmt = document.querySelector("button#btn-format");
const textArea = document.querySelector("textarea");

fetch("fmt.wasm")
  .then((response) => response.arrayBuffer())
  .then((bytes) => {
    const importObject = {
      env: {
        print: (result) => {
          console.log(`From wasm: ${result}`);
        },
      },
    };
    return WebAssembly.instantiate(bytes, importObject);
  })
  .then((result) => {
    const fmt = formatZigCode.bind(result.instance.exports);
    btnFmt.disabled = false;
    btnFmt.onclick = function () {
      textArea.value = fmt(textArea.value);
    };
  });
