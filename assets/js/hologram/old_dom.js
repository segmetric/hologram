"use strict";

import {attributesModule, eventListenersModule, h, init, toVNode} from "snabbdom";
const patch = init([attributesModule, eventListenersModule]);

import ClickEvent from "./events/click_event"
import Runtime from "./runtime"
import Utils from "./utils"

export default class VDOM {
  static PRUNED_ATTRS = ["on_click"]

  // TODO: refactor & test
  constructor(runtime, window) {
    this.document = window.document
    this.oldVNode = null
    this.runtime = runtime
    this.window = window
  }

  // TODO: already refactored; test
  getHTML() {
    const doctype = new XMLSerializer().serializeToString(this.document.doctype)
    const outerHTML = this.document.documentElement.outerHTML
    return doctype + outerHTML;
  }

  // TODO: refactor & test
  render(pageModule) {
    if (!this.oldVNode) {
      this.oldVNode = toVNode(this.document.documentElement)
    }

    const pageTemplate = pageModule.template()
    const layoutClassName = pageModule.layout().className
    const layoutTemplate = Runtime.getClassByClassName(layoutClassName).template()

    const context = {scopeModule: pageModule, pageModule: pageModule, slots: {default: pageTemplate}}

    let newVNode = this.buildVNode(layoutTemplate, this.runtime.state, this.runtime.state, context)[0]
    patch(this.oldVNode, newVNode)
    this.oldVNode = newVNode
  }

  // TODO: refactor & test
  reset() {
    this.oldVNode = null
  }
}