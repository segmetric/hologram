"use strict";

import Bitstring from "./bitstring.mjs";
import Elixir_Hologram_Router_Helpers from "./elixir/hologram/router/helpers.mjs";
import Elixir_Kernel from "./elixir/kernel.mjs";
import HologramBoxedError from "./errors/boxed_error.mjs";
import HologramInterpreterError from "./errors/interpreter_error.mjs";
import Interpreter from "./interpreter.mjs";
import MemoryStorage from "./memory_storage.mjs";
import Renderer from "./renderer.mjs";
import Store from "./store.mjs";
import Type from "./type.mjs";

// TODO: test
export default class Hologram {
  static deps = {
    Bitstring: Bitstring,
    HologramBoxedError: HologramBoxedError,
    HologramInterpreterError: HologramInterpreterError,
    Interpreter: Interpreter,
    MemoryStorage: MemoryStorage,
    Type: Type,
  };

  static assetPathRegistry = null;
  static isInitiated = false;
  static pageModule = null;
  static pageParams = null;

  static init() {
    window.Elixir_Hologram_Router_Helpers = Elixir_Hologram_Router_Helpers;
    window.Elixir_Kernel = Elixir_Kernel;

    window.console.inspect = (term) =>
      console.log("INSPECT: " + Interpreter.inspect(term));
  }

  static mountPage() {
    window.__hologramPageReachableFunctionDefs__(Hologram.deps);

    const mountData = Hologram.#loadMountData();

    Hologram.#maybeLoadAssetManifest();

    Renderer.renderPage(mountData.pageModule, mountData.pageParams);
  }

  static onReady(callback) {
    if (
      document.readyState === "interactive" ||
      document.readyState === "complete"
    ) {
      callback();
    } else {
      document.addEventListener("DOMContentLoaded", function listener() {
        document.removeEventListener("DOMContentLoaded", listener);
        callback();
      });
    }
  }

  static run() {
    Hologram.onReady(() => {
      if (!Hologram.isInitiated) {
        Hologram.init();
      }

      try {
        Hologram.mountPage();
      } catch (error) {
        if (error instanceof HologramBoxedError) {
          error.name = Interpreter.fetchErrorType(error);
          error.message = Interpreter.fetchErrorMessage(error);
        }

        throw error;
      }
    });
  }

  static #maybeLoadAssetManifest() {
    if (Hologram.assetPathRegistry === null) {
      Hologram.assetPathRegistry = window.__hologramAssetManifest__;
    }
  }

  static #loadMountData() {
    const mountData = window.__hologramPageMountData__(Hologram.deps);

    Store.hydrate(mountData.componentStructs);

    Hologram.pageModule = mountData.pageModule;
    Hologram.pageParams = mountData.pageParams;

    return mountData;
  }
}
