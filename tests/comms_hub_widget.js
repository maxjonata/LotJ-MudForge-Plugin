const widgetScript = require("./support/widget_script.js");
const assert = require('node:assert/strict');
const fs = require('node:fs');

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
const stats = ['damage-dealt', 'hits-given', 'misses', 'dodges', 'damage-taken', 'bacta-change'];
for (const stat of stats) elements.set('stat-' + stat, { textContent: '' });
const autopilot = { html: '' };
Object.defineProperty(autopilot, 'innerHTML', { set(value) { this.html = value; } });
elements.set('autopilot-content', autopilot);
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
widgetScript.run('src/widgets/lotj-comms-hub.lua', {
  document: {
    getElementById: (id) => elements.get(id),
    createElement: element,
    querySelectorAll: () => [],
  },
  mudforge: {
    onMessage(callback) { receive = callback; },
    escapeHTML: (text) => String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'),
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

receive({ event: 'combatStats', stats: { damageDealt: 120, hitsGiven: 7, misses: 2, dodges: 3, damageTaken: 40, bactaChange: -5 } });
assert.equal(elements.get('stat-damage-dealt').textContent, 120);
assert.equal(elements.get('stat-hits-given').textContent, 7);
assert.equal(elements.get('stat-misses').textContent, 2);
assert.equal(elements.get('stat-dodges').textContent, 3);
assert.equal(elements.get('stat-damage-taken').textContent, 40);
assert.equal(elements.get('stat-bacta-change').textContent, -5);
receive({ event: 'combatStats', stats: {} });
assert.equal(elements.get('stat-misses').textContent, 2, 'missing stats keep their values');
receive({ event: 'combatStats' });
console.log('PASS: combat stats fill their cells and ignore missing values');

receive({ event: 'autopilotRoute', route: { name: 'Kuat <run>', detail: '3 jumps & "fuel"' } });
assert.match(autopilot.html, /Kuat &lt;run&gt;/);
assert.match(autopilot.html, /3 jumps &amp; &quot;fuel&quot;/);
assert.doesNotMatch(autopilot.html, /<run>/, 'route text is escaped before innerHTML');
receive({ event: 'autopilotRoute', route: { name: 'Corellia' } });
assert.match(autopilot.html, /route-detail"><\/div>/);
receive({ event: 'autopilotRoute', route: {} });
assert.match(autopilot.html, /No active route/);
receive({ event: 'autopilotRoute' });
elements.delete('autopilot-content');
receive({ event: 'autopilotRoute', route: { name: 'Nowhere' } });
console.log('PASS: autopilot route renders escaped text or the empty state');
