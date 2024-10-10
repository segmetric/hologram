"use strict";

import {
  assert,
  defineGlobalErlangAndElixirModules,
} from "./support/helpers.mjs";

import PersistentStorage from "../../assets/js/persistent_storage.mjs";

import FDBDatabase from "../../assets/node_modules/fake-indexeddb/build/esm/FDBDatabase.js";
import FDBOpenDBRequest from "../../assets/node_modules/fake-indexeddb/build/esm/FDBOpenDBRequest.js";

defineGlobalErlangAndElixirModules();

describe("PersistentStorage", () => {
  it("init()", async () => {
    await PersistentStorage.reset();
    const result = await PersistentStorage.init("dev");

    assert.instanceOf(result, FDBDatabase);
    assert.equal(PersistentStorage.db, result);
    assert.equal(result.name, "hologram_dev");
    assert.equal(result.version, 1);

    assert.deepStrictEqual(PersistentStorage.db.objectStoreNames, [
      "pageSnapshots",
    ]);

    const objectStore = PersistentStorage.db
      .transaction("pageSnapshots", "readonly")
      .objectStore("pageSnapshots");

    assert.isNull(objectStore.keyPath);
    assert.isTrue(objectStore.autoIncrement);
    assert.deepStrictEqual(objectStore.indexNames, ["createdAt"]);

    const index = objectStore.index("createdAt");
    assert.equal(index.keyPath, "createdAt");
    assert.isFalse(index.multiEntry);
    assert.isFalse(index.unique);
  });

  it("putPageSnapshot()", async () => {
    await PersistentStorage.reset();
    await PersistentStorage.init("dev");

    const data = {a: 1, b: 2};
    const id = await PersistentStorage.putPageSnapshot(data);
    assert.equal(id, 1);

    const objects = await new Promise((resolve) => {
      PersistentStorage.db
        .transaction(
          PersistentStorage.PAGE_SNAPSHOTS_OBJ_STORE_NAME,
          "readonly",
        )
        .objectStore(PersistentStorage.PAGE_SNAPSHOTS_OBJ_STORE_NAME)
        .getAll().onsuccess = (event) => {
        resolve(event.target.result);
      };
    });

    const createdAt = objects[0].createdAt;
    assert.instanceOf(createdAt, Date);
    assert.deepStrictEqual(objects, [{data: data, createdAt: createdAt}]);

    const nowMs = Date.now();
    const createdAtMs = createdAt.getTime();
    assert.isAbove(nowMs, createdAtMs);
    assert.isAtMost(Math.abs(nowMs - createdAtMs), 3000);
  });
});
