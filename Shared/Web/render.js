/*
 * render.js — Markdown -> sanitized HTML. Shared by the app and the Quick Look extension.
 * Depends on the vendored libraries (markdown-it, plugins, highlight.js, DOMPurify) being
 * loaded first as globals. Exposes `MarkDwain.render(markdown)`.
 * Flow: viewer.js calls render() -> result HTML is inserted into the page.
 * The pure part (markdownToHtml) also runs in Node, which is how tests/render-test.js works.
 */
(function (root) {
  'use strict';

  /** GitHub-style heading slug: lowercase, drop punctuation, spaces to hyphens. Keeps unicode letters. */
  function slugify(text) {
    return String(text).trim().toLowerCase()
      .replace(/[^\p{L}\p{N}\p{M}_\- ]/gu, '')
      .replace(/ /g, '-');
  }

  /** Syntax highlighting hook for fenced code. Returns '' for unknown languages so markdown-it escapes them itself. */
  function highlight(code, lang, md) {
    if (lang && root.hljs && root.hljs.getLanguage(lang)) {
      try {
        const out = root.hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
        return '<pre><code class="hljs language-' + md.utils.escapeHtml(lang) + '">' + out + '</code></pre>';
      } catch (e) { /* fall through to plain rendering */ }
    }
    return '';
  }

  let md = null;
  /** Builds the markdown-it instance once. html:true because READMEs use raw HTML; DOMPurify cleans it afterwards. */
  function getMd() {
    if (md) return md;
    md = root.markdownit({ html: true, linkify: true, typographer: false, breaks: false,
      highlight: function (code, lang) { return highlight(code, lang, md); } });
    md.use(root.markdownItAnchor, { slugify: slugify, tabIndex: false });
    md.use(root.markdownitTaskLists, { enabled: false }); // read-only checkboxes
    md.use(root.markdownitFootnote);
    return md;
  }

  const FRONT_MATTER = /^---[ \t]*\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|$)/;

  /**
   * Converts Markdown to (unsanitized) HTML. YAML front matter becomes a collapsed <details> block
   * instead of being parsed as a horizontal rule + heading.
   */
  function markdownToHtml(source) {
    let text = String(source).replace(/^﻿/, '');
    let front = '';
    const m = FRONT_MATTER.exec(text);
    if (m) {
      text = text.slice(m[0].length);
      front = '<details class="frontmatter"><summary>Front matter</summary><pre>' +
        getMd().utils.escapeHtml(m[1]) + '</pre></details>';
    }
    return front + getMd().render(text);
  }

  /**
   * Full pipeline: Markdown -> HTML -> DOMPurify. Scripts, styles and forms are removed;
   * <img>, <details>, tables etc. survive. SANITIZE_DOM is off so headings named e.g. "Name" keep their id
   * (anchors would break otherwise); we never read DOM properties by name, so clobbering is harmless.
   */
  function render(source) {
    const html = markdownToHtml(source);
    if (!root.DOMPurify) return html; // only happens in Node tests
    return root.DOMPurify.sanitize(html, { SANITIZE_DOM: false, FORBID_TAGS: ['style', 'form'] });
  }

  root.MarkDwain = root.MarkDwain || {};
  root.MarkDwain.render = render;
  root.MarkDwain.markdownToHtml = markdownToHtml;
  root.MarkDwain.slugify = slugify;
})(typeof window !== 'undefined' ? window : globalThis);
