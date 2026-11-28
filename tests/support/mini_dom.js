// A tiny DOM for widget page scripts (UI-02): elements come from the start
// tags of the widget's markup, so ids, classes and data-* attributes match the
// real page. Supports the selectors the kit uses: [attr], [attr="v"], .a.b.
class ClassList {
  constructor(el) { this.el = el; }
  get names() { return (this.el.attributes.class || "").split(/\s+/).filter(Boolean); }
  set names(list) { this.el.attributes.class = list.join(" "); }
  add(name) { if (!this.contains(name)) this.names = this.names.concat(name); }
  remove(name) { this.names = this.names.filter(n => n !== name); }
  contains(name) { return this.names.includes(name); }
}

class Element {
  constructor(tag, attributes, document) {
    this.tagName = tag.toUpperCase();
    this.attributes = attributes;
    this.document = document;
    this.listeners = {};
    this.children = [];
    this.parent = null;
    this.text = "";
    this.value = attributes.value || "";
    this.hidden = "hidden" in attributes;
    this.style = { props: {}, setProperty(name, value) { this.props[name] = value; } };
    this.classList = new ClassList(this);
  }
  get textContent() { return this.text; }
  set textContent(value) { this.text = String(value); this.children = []; } // as in the DOM: replaces children
  get className() { return this.attributes.class || ""; }
  set className(value) { this.attributes.class = value; }
  get id() { return this.attributes.id; }
  getAttribute(name) { return name in this.attributes ? this.attributes[name] : null; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
  dispatch(type, event = {}) {
    const full = { target: this, preventDefault() { this.prevented = true; }, ...event };
    (this.listeners[type] || []).forEach(fn => fn(full));
    return full;
  }
  click() { return this.dispatch("click"); }
  focus() { this.document.activeElement = this; }
  appendChild(child) { child.parent = this; this.children.push(child); return child; }
  matches(selector) { return matches(this, selector); }
  closest(selector) {
    for (let el = this; el; el = el.parent) if (el.matches(selector)) return el;
    return null;
  }
}

function matchOne(el, selector) {
  const attr = /^\[([\w-]+)(?:="([^"]*)")?\]$/.exec(selector);
  if (attr) return attr[1] in el.attributes && (attr[2] === undefined || el.attributes[attr[1]] === attr[2]);
  if (selector.startsWith(".")) return selector.slice(1).split(".").every(name => el.classList.contains(name));
  return el.tagName === selector.toUpperCase();
}
function matches(el, selector) {
  return selector.split(",").some(part => matchOne(el, part.trim()));
}

function parseAttributes(text) {
  const attributes = {};
  for (const m of text.matchAll(/([\w-]+)(?:="([^"]*)")?/g)) attributes[m[1]] = m[2] === undefined ? "" : m[2];
  return attributes;
}

function createDocument(markup) {
  const document = {
    all: [], activeElement: null,
    documentElement: null, body: null,
    getElementById(id) { return this.all.find(el => el.id === id) || null; },
    querySelectorAll(selector) { return this.all.filter(el => el.parent !== null && el.matches(selector)); },
    createElement(tag) { return new Element(tag, {}, this); },
  };
  document.documentElement = new Element("html", {}, document);
  document.body = new Element("body", { class: "script" }, document);
  const stack = [document.body];
  document.body.parent = document.documentElement;
  const voids = new Set(["input", "meta", "br", "img"]);
  for (const m of markup.matchAll(/<(\/?)([a-zA-Z][\w-]*)([^>]*)>/g)) {
    const [, closing, tag, rest] = m;
    if (closing) { stack.pop(); continue; }
    const el = new Element(tag, parseAttributes(rest), document);
    stack[stack.length - 1].appendChild(el);
    document.all.push(el);
    if (!voids.has(tag.toLowerCase()) && !rest.trim().endsWith("/")) stack.push(el);
  }
  return document;
}

// A sandbox with the mudforge bridge recorded in `posted`.
function sandbox(markup) {
  const document = createDocument(markup);
  const posted = [];
  const frames = [];
  const env = {
    document, posted, frames,
    Array, Number, String, Object, JSON, Math,
    requestAnimationFrame: fn => frames.push(fn),
    mudforge: {
      send: (event, data) => posted.push([event, JSON.parse(JSON.stringify(data))]),
      onMessage: fn => { env.receive = fn; },
    },
  };
  return env;
}

module.exports = { createDocument, sandbox };
