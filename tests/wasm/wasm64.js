const wasm = require("wasm-bindgen-test");

// Verify that pointer-sized values returned from Wasm are BigInt (64-bit) rather than Number.
exports.js_verify_pointer_size = function () {
  const val = wasm.wasm64_return_usize();
  // On wasm64, usize maps to i64 which becomes BigInt in JS
  if (typeof val !== "bigint") {
    throw new Error(`Expected bigint, got ${typeof val}: ${val}`);
  }
  // Check the value is correct (0x1_0000_0001 = 4294967297)
  if (val !== 4294967297n) {
    throw new Error(`Expected 4294967297n, got ${val}`);
  }
  return true;
};

// Round-trip a slice through JS to verify 64-bit pointer/length handling in slice passing.
exports.js_roundtrip_large_slice = function (slice) {
  // Verify we received a proper Uint8Array
  if (!(slice instanceof Uint8Array)) {
    throw new Error(`Expected Uint8Array, got ${typeof slice}`);
  }
  // Return it back as a Vec<u8>
  return slice;
};

// Test creating and freeing a class instance to exercise the BigInt(ptr) free path.
exports.js_create_and_free_class = function () {
  const obj = new wasm.Wasm64TestClass(42n);
  if (obj.get_value() !== 42n) {
    throw new Error(`Expected 42n, got ${obj.get_value()}`);
  }
  if (obj.add(8n) !== 50n) {
    throw new Error(`Expected 50n, got ${obj.add(8n)}`);
  }
  // Free the object - this exercises the BigInt(ptr) free function path
  obj.free();
  return true;
};

// Test that closures work correctly with 64-bit return values.
exports.js_call_closure_returning_usize = function () {
  const val = wasm.wasm64_closure_returning_usize();
  if (typeof val !== "bigint") {
    throw new Error(`Expected bigint, got ${typeof val}: ${val}`);
  }
  if (val !== 4294967297n) {
    throw new Error(`Expected 4294967297n, got ${val}`);
  }
  return true;
};
