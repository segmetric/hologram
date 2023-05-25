"use strict";

import Interpreter from "./interpreter.mjs";
import Utils from "./utils.mjs";

export default class Type {
  static atom(value) {
    return Utils.freeze({type: "atom", value: value});
  }

  static bitstring(segments) {
    segments.forEach((segment, index) =>
      Type._validateBitstringSegment(segment, index + 1)
    );

    const bits = segments.reduce((acc, segment) => {
      const segmentArr = Type._buildBitstringSegmentBitArray(segment);

      const mergedArr = new Uint8Array(acc.length + segmentArr.length);
      mergedArr.set(acc);
      mergedArr.set(segmentArr, acc.length);

      return mergedArr;
    }, new Uint8Array());

    // Cannot freeze array buffer views with elements
    return {type: "bitstring", bits: bits};
  }

  static boolean(value) {
    return Type.atom(value.toString());
  }

  static consPattern(head, tail) {
    return Utils.freeze({type: "cons_pattern", head: head, tail: tail});
  }

  static encodeMapKey(boxed) {
    switch (boxed.type) {
      case "atom":
      case "float":
      case "integer":
      case "string":
        return Type._encodePrimitiveTypeMapKey(boxed);

      case "bitstring":
        return Type._encodeBitstringTypeMapKey(boxed);

      case "list":
      case "tuple":
        return Type._encodeEnumTypeMapKey(boxed);

      case "map":
        return Type._encodeMapTypeMapKey(boxed);
    }
  }

  static float(value) {
    return Utils.freeze({type: "float", value: value});
  }

  static integer(value) {
    if (typeof value !== "bigint") {
      value = BigInt(value);
    }

    return Utils.freeze({type: "integer", value: value});
  }

  static isAtom(boxed) {
    return boxed.type === "atom";
  }

  static isConsPattern(boxed) {
    return boxed.type === "cons_pattern";
  }

  static isFalse(boxed) {
    return Type.isAtom(boxed) && boxed.value === "false";
  }

  static isFloat(boxed) {
    return boxed.type === "float";
  }

  static isInteger(boxed) {
    return boxed.type === "integer";
  }

  static isList(boxed) {
    return boxed.type === "list";
  }

  static isMap(boxed) {
    return boxed.type === "map";
  }

  static isNumber(boxed) {
    return Type.isInteger(boxed) || Type.isFloat(boxed);
  }

  static isTrue(boxed) {
    return Type.isAtom(boxed) && boxed.value === "true";
  }

  static isVariablePattern(boxed) {
    return boxed.type === "variable_pattern";
  }

  static list(data) {
    return Utils.freeze({type: "list", data: data});
  }

  static map(data) {
    const hashTableWithMetadata = data.reduce((acc, [boxedKey, boxedValue]) => {
      acc[Type.encodeMapKey(boxedKey)] = [boxedKey, boxedValue];
      return acc;
    }, {});

    return Utils.freeze({type: "map", data: hashTableWithMetadata});
  }

  static string(value) {
    return Utils.freeze({type: "string", value: value});
  }

  static tuple(data) {
    return Utils.freeze({type: "tuple", data: data});
  }

  static variablePattern(name) {
    return Utils.freeze({type: "variable_pattern", name: name});
  }

  // private
  static _buildBitArrayFromBitstring(bits) {
    return new Uint8Array(bits);
  }

  // private
  static _buildBitArrayFromInteger(data, size, unit) {
    // clamp to size number of bits
    const numBits = size * unit;
    const bitmask = 2n ** numBits - 1n;
    data = data & bitmask;

    const bitArr = [];

    for (let i = numBits; i >= 1n; --i) {
      bitArr[numBits - i] = Type._getBit(data, i - 1n);
    }

    return new Uint8Array(bitArr);
  }

  // private
  static _buildBitstringSegmentBitArray(segment) {
    let type, data, size, unit, rest;
    [type, data, size, unit, ...rest] = segment;

    switch (type) {
      case "bitstring":
        return Type._buildBitArrayFromBitstring(data.bits);

      case "integer":
        return Type._buildBitArrayFromInteger(data.value, size.value, unit);
    }
  }

  // private
  static _encodeBitstringTypeMapKey(boxed) {
    return "bitstring(" + boxed.bits.join("") + ")";
  }

  // private
  static _encodeEnumTypeMapKey(boxed) {
    const itemsStr = boxed.data
      .map((item) => Type.encodeMapKey(item))
      .join(",");

    return boxed.type + "(" + itemsStr + ")";
  }

  // private
  static _encodeMapTypeMapKey(boxed) {
    const itemsStr = Object.keys(boxed.data)
      .sort()
      .map((key) => key + ":" + Type.encodeMapKey(boxed.data[key][1]))
      .join(",");

    return "map(" + itemsStr + ")";
  }

  // private
  static _encodePrimitiveTypeMapKey(boxed) {
    return `${boxed.type}(${boxed.value})`;
  }

  // private
  static _getBit(value, position) {
    return (value & (1n << position)) === 0n ? 0 : 1;
  }

  // private
  static _validateBitstringSegment(segment, index) {
    let type, data, rest;
    [type, data, ...rest] = segment;

    // iex> x = 123.45
    // iex> <<x::integer>
    if (data.type !== type) {
      const inspectedValue = Interpreter.inspect(data.value);
      const indefiniteArticle = Utils.indefiniteArticle(type);
      const message = `construction of binary failed: segment ${index} of type '${type}': expected ${indefiniteArticle} ${type} but got: ${inspectedValue}`;
      Interpreter.raiseError("ArgumentError", message);
    }
  }
}
