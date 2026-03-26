const wasm = require('wasm-bindgen-test.js');
const assert = require('assert');

const isWasm64 = () => typeof wasm.wasm64_return_usize === 'function';
const scalar64 = value => isWasm64() ? Number(value) : value;

exports.i64_js_identity = a => a;
exports.u64_js_identity = a => a;

exports.js_works = () => {
    assert.strictEqual(wasm.zero(), scalar64(0n));
    assert.strictEqual(wasm.one(), scalar64(1n));
    assert.strictEqual(wasm.neg_one(), scalar64(-1n));
    assert.strictEqual(wasm.i32_min(), scalar64(-2147483648n));
    assert.strictEqual(wasm.u32_max(), scalar64(4294967295n));
    assert.strictEqual(wasm.i64_min(), scalar64(-9223372036854775808n));
    assert.strictEqual(wasm.u64_max(), scalar64(18446744073709551615n));

    const i64_min = BigInt('-9223372036854775808');
    const u64_max = BigInt('18446744073709551615');

    const identityTestI64Values = isWasm64()
        ? [0, 1, -1, Number(i64_min)]
        : [BigInt('0'), BigInt('1'), BigInt('-1'), i64_min];
    for (const value of identityTestI64Values) {
        assert.strictEqual(wasm.i64_rust_identity(value), value);
    }

    const jsValueI64Values = isWasm64()
        ? [BigInt('0'), BigInt('1'), BigInt('-1'), i64_min]
        : identityTestI64Values;
    for (const value of jsValueI64Values) {
        assert.strictEqual(
            wasm.i64_jsvalue_identity(isWasm64() ? Number(value) : value),
            value,
        );
    }

    const identityTestU64Values = isWasm64()
        ? [0, 1]
        : [BigInt('0'), BigInt('1'), u64_max];
    for (const value of identityTestU64Values) {
        assert.strictEqual(wasm.u64_rust_identity(value), value);
    }

    const jsValueU64Values = isWasm64()
        ? [BigInt('0'), BigInt('1')]
        : identityTestU64Values;
    for (const value of jsValueU64Values) {
        assert.strictEqual(
            wasm.u64_jsvalue_identity(isWasm64() ? Number(value) : value),
            value,
        );
    }

    if (!isWasm64()) {
        assert.strictEqual(wasm.u64_rust_identity(BigInt('1') << BigInt('64')), BigInt('0'));
    }
    assert.strictEqual(wasm.i128_min_jsvalue(), BigInt('-170141183460469231731687303715884105728'));
    assert.strictEqual(wasm.u128_max_jsvalue(), BigInt('340282366920938463463374607431768211455'));

    assert.deepStrictEqual(wasm.u64_slice([]), new BigUint64Array());
    assert.deepStrictEqual(wasm.i64_slice([]), new BigInt64Array());
    const arr1 = new BigUint64Array([BigInt('1'), BigInt('2')]);
    assert.deepStrictEqual(wasm.u64_slice([BigInt('1'), BigInt('2')]), arr1);
    const arr2 = new BigInt64Array([BigInt('1'), BigInt('2')]);
    assert.deepStrictEqual(wasm.i64_slice([BigInt('1'), BigInt('2')]), arr2);

    assert.deepStrictEqual(wasm.i64_slice([i64_min]), new BigInt64Array([i64_min]));
    assert.deepStrictEqual(wasm.u64_slice([u64_max]), new BigUint64Array([u64_max]));
};
