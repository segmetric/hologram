"use strict";

import Bitstring from "./bitstring.mjs";
import Type from "./type.mjs";

import {h as vnode} from "snabbdom";

// Based on Hologram.Template.Renderer
export default class Renderer {
  // Based on render_dom/3
  static renderDom(dom, context, slots) {
    if (Type.isList(dom)) {
      return Renderer.#renderNodes(dom, context, slots);
    }

    const nodeType = dom.data[0].value;

    switch (nodeType) {
      case "element":
        return Renderer.#renderElement(dom, context, slots);

      case "expression":
        return Bitstring.toText(
          Elixir_Kernel["to_string/1"](dom.data[1].data[0]),
        );

      case "text":
        return Bitstring.toText(dom.data[1]);
    }
  }

  // Based on render_attribute/2
  static #renderAttribute(name, valueDom) {
    const nameStr = Bitstring.toText(name);

    if (valueDom.data.length === 0) {
      return [nameStr, true];
    }

    const valueStr = Renderer.renderDom(
      valueDom,
      Type.map([]),
      Type.keywordList([]),
    ).join("");

    return [nameStr, valueStr];
  }

  // Based on render_attributes/1
  static #renderAttributes(attrsDom) {
    if (attrsDom.data.length === 0) {
      return {};
    }

    return attrsDom.data.reduce((acc, attrDom) => {
      const [nameStr, valueStr] = Renderer.#renderAttribute(
        attrDom.data[0],
        attrDom.data[1],
      );

      acc[nameStr] = valueStr;

      return acc;
    }, {});
  }

  // Based on render_dom/3 (element & slot case)
  static #renderElement(dom, context, slots) {
    const tagName = Bitstring.toText(dom.data[1]);

    if (tagName === "slot") {
      return Renderer.#renderSlotElement(slots, context);
    }

    const attrsDom = dom.data[2];
    const childrenDom = dom.data[3];

    const attrsVdom = Renderer.#renderAttributes(attrsDom);
    const childrenVdom = Renderer.renderDom(childrenDom, context, slots);

    return vnode(tagName, {attrs: attrsVdom}, childrenVdom);
  }

  // Based on render_dom/3 (list case)
  static #renderNodes(nodes, context, slots) {
    return (
      nodes.data
        // There may be nil DOM nodes resulting from "if" blocks, e.g. {%if false}abc{/if}
        .filter((node) => !Type.isNil(node))
        .map((node) => Renderer.renderDom(node, context, slots))
    );
  }

  // Based on render_dom/3 (slot case)
  static #renderSlotElement(slots, context) {
    const slotDom = Erlang_Lists["keyfind/3"](
      Type.atom("default"),
      Type.integer(1),
      slots,
    ).data[1];

    return Renderer.renderDom(slotDom, context, Type.keywordList([]));
  }
}

// import Erlang_Maps from "./erlang/maps.mjs";
// import HologramInterpreterError from "./errors/interpreter_error.mjs";
// import Interpreter from "./interpreter.mjs";
// import Store from "./store.mjs";

//   // Based on: render_page/2
//   static renderPage(pageModule, pageParams) {
//     const pageModuleRef = Interpreter.moduleRef(pageModule);
//     const layoutModule = pageModuleRef["__layout_module__/0"]();

//     const cid = Type.bitstring("page");
//     const pageClientStruct = Store.getComponentData(cid);
//     const pageState = Store.getComponentState(cid);
//     const pageContext = Store.getComponentContext(cid);

//     const layoutPropsDOM = Renderer.#buildLayoutPropsDOM(
//       pageModuleRef,
//       pageClientStruct,
//     );

//     const vars = Renderer.#buildVars(pageParams, pageState);
//     const pageDOM = Renderer.#evaluateTemplate(pageModuleRef, vars);

//     const layoutNode = Type.tuple([
//       Type.atom("component"),
//       layoutModule,
//       layoutPropsDOM,
//       pageDOM,
//     ]);

//     const html = Renderer.#renderDom(layoutNode, pageContext, Type.list([]));

//     // TODO: remove
//     console.inspect(html);
//   }

//   static #renderDom(dom, context, slots) {
//       switch (nodeType) {
//         case "component":
//           return Renderer.#renderComponentDOM(dom, context, slots);

//         case "element": {
//           const tagName = dom.data[0].value;
//           if (tagName === "slot") {
//             return "(todo: slot)";
//           }
//           return "(todo: element)";
//         }
//       }
//     }
//   }

//   static #buildVars(props, state) {
//     return Erlang_Maps["merge/2"](props, state);
//   }

//   // TODO: finish
//   static #buildLayoutPropsDOM(pageModuleRef, pageClientStruct) {
//     pageModuleRef["__layout_props__/0"]().data.concat(
//       Type.tuple([Type.atom("cid", Type.bitstring("layout"))]),
//     );
//   }

//   static #castProps(propsDOM, module) {
//     return Elixir_Hologram_Template_Renderer["cast_props/2"](propsDOM, module);
//   }

//   static #evaluateTemplate(moduleRef, vars) {
//     return Interpreter.callAnonymousFunction(moduleRef["template/0"](), [vars]);
//   }

//   static #expandSlots(dom, slots) {
//     return Elixir_Hologram_Template_Renderer["expand_slots/2"](dom, slots);
//   }

//   static #hasCidProp(props) {
//     return Elixir_Hologram_Template_Renderer["has_cid_prop?/1"](props);
//   }

//   static #injectPropsFromContext(propsFromTemplate, module, context) {
//     return Elixir_Hologram_Template_Renderer["inject_props_from_context/3"](
//       propsFromTemplate,
//       module,
//       context,
//     );
//   }

//   static #renderComponentDOM(dom, context, slots) {
//     const module = dom.data[1];
//     const propsDOM = dom.data[2];
//     let children = dom.data[3];

//     const expandedChildren = Renderer.#expandSlots(children, slots);

//     const props = Renderer.#injectPropsFromContext(
//       Renderer.#castProps(propsDOM, module),
//       module,
//       context,
//     );

//     if (Type.isTrue(Renderer.#hasCidProp(props))) {
//       return Renderer.#renderStatefulComponent(
//         module,
//         props,
//         expandedChildren,
//         context,
//       );
//     } else {
//       return Renderer.#renderStatelessComponent(
//         module,
//         props,
//         expandedChildren,
//         context,
//       );
//     }
//   }

//   static #renderStatefulComponent(module, props, children, context) {
//     const cid = Erlang_Maps["get/2"](Type.atom("cid"), props);
//     let componentState = Store.getComponentState(cid);
//     let componentContext;

//     const moduleRef = Interpreter.moduleRef(module);

//     if (componentState === null) {
//       if ("init/2" in moduleRef) {
//         const emptyClientStruct =
//           Elixir_Hologram_Component_Client["__struct__/0"]();

//         const clientStruct = moduleRef["init/2"](props, emptyClientStruct);

//         componentState = Erlang_Maps["get/2"](Type.atom("state"), clientStruct);

//         componentContext = Erlang_Maps["get/2"](
//           Type.atom("context"),
//           clientStruct,
//         );
//       } else {
//         const message = `component ${Interpreter.inspect(
//           module,
//         )} is initialized on the client, but doesn't have init/2 implemented`;

//         throw new HologramInterpreterError(message);
//       }
//     } else {
//       componentContext = Store.getComponentContext(cid);
//     }

//     const vars = Renderer.#buildVars(props, componentState);
//     const mergedContext = Erlang_Maps["merge/2"](context, componentContext);

//     const template = Renderer.#renderTemplate(
//       moduleRef,
//       vars,
//       children,
//       mergedContext,
//     );

//     // TODO: remove
//     console.inspect(template);

//     return "(todo: component, in progress)";
//   }

//   // TODO: implement
//   static #renderStatelessComponent() {
//     console.log("#renderStatelessComponent()");
//   }

//   static #renderTemplate(moduleRef, vars, children, context) {
//     const dom = Renderer.#evaluateTemplate(moduleRef, vars);
//     const slots = Type.keywordList([[Type.atom("default"), children]]);

//     return Renderer.#renderDom(dom, context, slots);
//   }
