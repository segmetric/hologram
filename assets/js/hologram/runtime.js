"use strict";

import Action from "./action";
import Client from "./client"
import Command from "./command"
import DOM from "./dom"
import Operation from "./operation"
import ScriptsReloader from "./scripts_reloader"
import Store from "./store";
import Utils from "./utils"

export default class Runtime {
  static getInstance() {
    if (!globalThis.__hologramRuntime__) {
      globalThis.__hologramRuntime__ = new Runtime()
    }

    return globalThis.__hologramRuntime__
  }

  // Tested implicitely in E2E tests.
  static executeOperation(operation) {
    if (operation.method === Operation.METHOD.action) {
      Action.execute(operation)
    } else {
      Command.execute(operation)
    }
  }

  static getComponentClass(componentId) {
    return Runtime.componentClassRegistry[componentId]
  }

  // Tested implicitely in E2E tests.
  static handleEvent(event, eventImplementation, source, bindings, operationSpec) {
    event.preventDefault()

    const eventData = eventImplementation.buildEventData(event)
    const operation = Operation.build(operationSpec, source, bindings, eventData)

    Runtime.executeOperation(operation)
  }













  constructor() {
    this.client = new Client()
    this.client.connect()

    this.document = globalThis.window.document
    this.dom = new DOM(this, window)
    this.pageModule = null
    this.state = null
    this.store = new Store()
    this.window = globalThis.window

    Runtime.componentClassRegistry = {}

    this.loadPageOnPopStateEvents()
  }
  
  

  // TODO: refactor & test
  static getModule(module) {
    let name;

    if (module.type == "module") {
      name = module.className
    } else {
      name = module
    }

    return Utils.eval(name.replace(/\./g, ""))
  }  
  
  processCommand() {
    // this.pushCommand(eventHandlerSpec, context)
    this.client.pushCommand(context.pageModule, commandName, commandParams, this.handleCommandResponse)
  }
 
  // TODO: refactor & test
  redirect(params) {
    const html = params.data["~atom[html]"].value
    this.loadPage(html)

    const url = params.data["~atom[url]"].value
    this.updateURL(url)
  }

  // TODO: refactor & test
  loadPage(html) {
    // TODO: copy html node attributes (because only the inner HTML is updated)
    this.document.documentElement.innerHTML = html

    this.dom.reset()
    ScriptsReloader.reload(this.document)
  }

  // TODO: refactor & test
  loadPageOnPopStateEvents() {
    this.window.addEventListener("popstate", event => {
      this.loadPage(event.state)
    })
  }

  // TODO: refactor & test
  mountPage(pageModule, serializedState) {
    this.state = Utils.eval(serializedState, false)
    this.state.data["~atom[context]"].data['~atom[__state__]'] = {type: "string", value: serializedState}
    Utils.freeze(this.state)

    this.pageModule = pageModule
    this.dom.render(this.pageModule)

    const html = this.dom.getHTML()
    // DEFER: consider - there are limitations for state object size, e.g. 2 MB for Firefox
    this.window.history.replaceState(html, null)
  }

  // TODO: refactor & test
  updateURL(url) {
    this.window.history.pushState(null, null, url)
  }
}