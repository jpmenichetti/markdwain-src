/*
 * render-test.js — small Node test for Shared/Web/render.js (the unsanitized Markdown pipeline).
 * Loads the vendored libraries into one VM context exactly like the page does with <script> tags.
 * Run: node tests/render-test.js   (DOMPurify needs a DOM, so sanitizing is checked in the app, not here)
 */
const vm = require('vm'), fs = require('fs'), path = require('path'), assert = require('assert');
const web = path.join(__dirname, '..', 'Shared', 'Web');
const ctx = vm.createContext({}); ctx.globalThis = ctx;
for (const f of ['vendor/markdown-it.min.js', 'vendor/markdownItAnchor.umd.js', 'vendor/markdown-it-task-lists.min.js',
  'vendor/markdown-it-footnote.min.js', 'vendor/highlight.min.js', 'render.js']) {
  vm.runInContext(fs.readFileSync(path.join(web, f), 'utf8'), ctx, { filename: f });
}
const html = (s) => ctx.MarkDwain.markdownToHtml(s);

assert.match(html('| a | b |\n|---|---|\n| 1 | 2 |'), /<table>/);
assert.match(html('~~gone~~'), /<s>gone<\/s>/);
assert.match(html('- [x] done\n- [ ] todo'), /disabled="" type="checkbox"/);
assert.match(html('```js\nconst a = 1;\n```'), /hljs language-js/);
assert.match(html('```nonsense\nx\n```'), /<pre><code class="language-nonsense">/);
assert.match(html('# Hello, World!'), /id="hello-world"/);
assert.match(html('# Dup\n# Dup'), /id="dup-1"/);
assert.match(html('---\ntitle: x\n---\n# Body'), /<details class="frontmatter">[\s\S]*title: x[\s\S]*<h1/);
assert.doesNotMatch(html('---\ntitle: x\n---\n# Body'), /<hr/);
assert.match(html('See http://example.com'), /<a href="http:\/\/example.com"/);
assert.match(html('Note[^1]\n\n[^1]: text'), /footnote/);
console.log('render-test: all assertions passed');
