import {attributesModule, eventListenersModule, h, init, toVNode} from "snabbdom";
const patch = init([attributesModule, eventListenersModule]);

import Runtime from "./runtime"

export default class DOM {
  static PRUNED_ATTRS = ["on_click"]

  // TODO: refactor & test
  constructor(runtime, window) {
    this.document = window.document
    this.oldVNode = null
    this.runtime = runtime
    this.window = window
  }

  // TODO: refactor & test
  buildVNode(node, state, context) {
    if (Array.isArray(node)) {
      return node.reduce((acc, n) => {
        acc.push(...this.buildVNode(n, state, context))
        return acc
      }, [])
    }

    switch (node.type) {
      case "component":
        let module = Runtime.getModule(node.module)

        if (DOM.hasActionHandlers(module)) {
          context = Object.assign({}, context)
          context.scopeModule = module
        }

        context.slots = { default: node.children }

        return this.buildVNode(module.template(), state, context)

      case "element":
        if (node.tag == "slot") {
          return this.buildVNode(context.slots.default, state, context)
        }

        let children = node.children.reduce((acc, child) => {
          acc.push(...this.buildVNode(child, state, context))
          return acc
        }, [])

        let event_handlers = this.buildVNodeEventHandlers(node, state, context)
        let attrs = DOM.buildVNodeAttrs(node, state)

        return [h(node.tag, {attrs: attrs, on: event_handlers}, children)]

      case "expression":
        const evaluatedExpression = node.callback(state).data[0]
        return [Runtime.interpolate(evaluatedExpression)]

      case "text":
        return [node.content]
    } 
  }

  static buildVNodeAttrs(node, state) {
    return Object.keys(node.attrs).reduce((acc, key) => {
      if (!DOM.PRUNED_ATTRS.includes(key)) {
        acc[key] = DOM.evaluateAttributeValue(node.attrs[key].value, state)
      }
      return acc
    }, {})
  }

  // TODO: refactor & test
  // DEFER: research whether this creates a new handler on each render (how to optimize it?)
  buildVNodeEventHandlers(node, state, context) {
    const eventHandlers = {}

    if (node.attrs.on_click) {
      eventHandlers.click = this.runtime.handleClickEvent.bind(this.runtime, node.attrs.on_click, state, context)
    }

    if (node.attrs.on_submit) {
      eventHandlers.submit = this.runtime.handleSubmitEvent.bind(this.runtime, context, node.attrs.on_submit, state)
    }

    return eventHandlers
  }

  static evaluateAttributeValue(value, state) {
    if (value.type == "expression") {
      const result = value.callback(state).data[0]
      return Runtime.interpolate(result)

    } else {
      return value
    }
  }

  // TODO: already refactored; test
  getHTML() {
    const doctype = new XMLSerializer().serializeToString(this.document.doctype)
    const outerHTML = this.document.documentElement.outerHTML
    return doctype + outerHTML;
  }

  // TODO: already refactored; test
  static hasActionHandlers(module) {
    return module.hasOwnProperty("action")
  }

  // TODO: refactor & test
  render(pageModule) {
    if (!this.oldVNode) {
      const container = this.document.body
      this.oldVNode = toVNode(container)
    }

    let context = {scopeModule: pageModule, pageModule: pageModule}
    let template = context.pageModule.template()

    let newVNode = this.buildVNode(template, this.runtime.state, context)[0]
    patch(this.oldVNode, newVNode)
    this.oldVNode = newVNode
  }

  // TODO: refactor & test
  reset() {
    this.oldVNode = null
  }
}