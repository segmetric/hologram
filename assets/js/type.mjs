"use strict";

import Utils from "./utils.mjs";

export default class Type {
  static atom(value) {
    return Utils.freeze({type: "atom", value: value});
  }

  static boolean(value) {
    return Type.atom(value.toString());
  }

  static consPattern(head, tail) {
    return Utils.freeze({type: "cons_pattern", head: head, tail: tail});
  }

  // private
  static _encodeEnumTypeMapKey(boxed) {
    const itemsStr = boxed.data
      .map((item) => Type.encodeMapKey(item))
      .join(",");

    return boxed.type + "(" + itemsStr + ")";
  }

  static encodeMapKey(boxed) {
    switch (boxed.type) {
      case "atom":
      case "float":
      case "integer":
      case "string":
        return Type._encodePrimitiveTypeMapKey(boxed);

      case "list":
      case "tuple":
        return Type._encodeEnumTypeMapKey(boxed);

      case "map":
        return Type._encodeMapTypeMapKey(boxed);
    }
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

  static float(value) {
    return Utils.freeze({type: "float", value: value});
  }

  static integer(value) {
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
}
