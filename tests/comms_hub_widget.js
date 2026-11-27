const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function element() {
  return {
    children: [], style: {}, classList: { add() {}, remove() {} },
    appendChild(child) {
      this.children.push(child);
      child.remove = () => this.children.splice(this.children.indexOf(child), 1);
    },
    replaceChildren() { this.children.length = 0; },
    get childElementCount() { return this.children.length; },
    get firstElementChild() { return this.children[0]; },
    set innerHTML(value) { throw new Error('Unexpected HTML rendering: ' + value); },
  };
}

const channels = ['all', 'local', 'commnet', 'clan', 'broadcast', 'ooc', 'tell', 'imm'];
const elements = new Map([['tabs', element()]]);
for (const channel of channels) {
  elements.set('tab-' + channel, element());
  if (channel !== 'all') elements.set('lotj-' + channel + '-badge', element());
}
let select, receive;
elements.get('tabs').addEventListener = (event, callback) => {
  assert.equal(event, 'click');
  select = (channel) => callback({
    target: { closest: () => ({ classList: { add() {} }, getAttribute: () => channel }) },
  });
};
const posts = [];
const source = fs.readFileSync('src/widgets/lotj-comms-hub.lua', 'utf8');
const [ , script ] = source.match(/<script>([\s\S]+?)<\/script>/);
vm.runInNewContext(script, {
  document: {
    getElementById: (id) => elements.get(id),
    createElement: element,
    querySelectorAll: () => [],
  },
  mudforge: {
    onMessage(callback) { receive = callback; },
    send(event, payload) {
      assert.ok(receive, 'install the receiver before announcing ready');
      posts.push([event, payload]);
    },
  },
});
const chat = (channel, text) => receive({ event: 'chatMessage', msg: { channel, sender: 'Pilot', text } });
const tab = (channel) => elements.get('tab-' + channel);
const badge = (channel) => elements.get('lotj-' + channel + '-badge');
assert.equal(posts[0][0], 'ready');

chat('local', '<img src=invalid>');
assert.equal(tab('local').childElementCount, 1);
assert.equal(tab('all').childElementCount, 1);
assert.equal(tab('all').firstElementChild.children.at(-1).textContent, '<img src=invalid>');
assert.equal(badge('local').textContent, 1);
assert.equal(posts.length, 1, 'receiving chat must not request prompt focus');
select('local');
assert.equal(posts.at(-1)[0], 'tabClick');
assert.equal(posts.at(-1)[1].tab, 'local');
chat('local', 'Still reading');
assert.equal(badge('local').style.display, 'none');

chat('nonsense', 'One copy in All');
assert.equal(tab('all').childElementCount, 3);
assert.equal(tab('local').childElementCount, 2);
for (let i = 0; i < 251; i++) chat('commnet', String(i));
assert.equal(tab('commnet').childElementCount, 250);
assert.equal(tab('all').childElementCount, 250);
assert.equal(tab('all').firstElementChild.children.at(-1).textContent, '1');
assert.equal(badge('commnet').textContent, 250);

receive({ event: 'chatReset' });
assert.equal(tab('all').childElementCount, 0);
assert.equal(tab('commnet').childElementCount, 0);
assert.equal(badge('commnet').textContent, 0);
console.log('PASS: chat mirrors once, renders text safely, tracks unread counts and bounds per-session history');
