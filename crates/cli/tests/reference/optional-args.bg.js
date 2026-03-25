/**
 * @param {number | null} [a]
 * @param {number | null} [b]
 * @param {number | null} [c]
 */
export function all_optional(a, b, c) {
    wasm.all_optional(isLikeNone(a) ? 9007199254740991 : (a) >>> 0, isLikeNone(b) ? 9007199254740991 : (b) >>> 0, isLikeNone(c) ? 9007199254740991 : (c) >>> 0);
}

/**
 * @param {number | null | undefined} a
 * @param {number} b
 * @param {number | null} [c]
 */
export function some_optional(a, b, c) {
    wasm.some_optional(isLikeNone(a) ? 9007199254740991 : (a) >>> 0, b, isLikeNone(c) ? 9007199254740991 : (c) >>> 0);
}
export function __wbindgen_init_externref_table() {
    const table = wasm.__wbindgen_externrefs;
    const offset = table.grow(4);
    table.set(0, undefined);
    table.set(offset + 0, undefined);
    table.set(offset + 1, null);
    table.set(offset + 2, true);
    table.set(offset + 3, false);
}
function isLikeNone(x) {
    return x === undefined || x === null;
}


let wasm;
export function __wbg_set_wasm(val) {
    wasm = val;
}
