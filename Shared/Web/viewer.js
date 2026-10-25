/*
 * viewer.js — page behaviour: renders Markdown into #content, builds the TOC sidebar, highlights the
 * current section, intercepts link clicks, shows the "file missing" banner and link hover bar.
 * Depends on render.js. Native code (app) calls boot/update/setSidebar/setMissing/scrollToId;
 * the page talks back through window.webkit.messageHandlers.mdw (absent in Quick Look).
 */
(function () {
  'use strict';

  const $ = (id) => document.getElementById(id);
  let headings = [];
  let sidebarWanted = false;
  let preview = false;

  /** Sends a message to the native app. No-op inside Quick Look, where no handler is registered. */
  function post(msg) {
    const h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mdw;
    if (h) h.postMessage(msg);
  }

  /** Scrolls to the element with the given id (tries the raw and the percent-decoded form). Returns success. */
  function scrollToId(id) {
    let decoded = id;
    try { decoded = decodeURIComponent(id); } catch (e) { /* keep raw */ }
    const el = document.getElementById(id) || document.getElementById(decoded);
    if (el) el.scrollIntoView();
    return !!el;
  }

  /** Rebuilds the sidebar list from h1–h4 and shows/hides it (hidden when the document has no headings). */
  function buildToc() {
    headings = Array.from($('content').querySelectorAll('h1[id],h2[id],h3[id],h4[id]'));
    const list = $('toc-list');
    list.textContent = '';
    headings.forEach((h) => {
      const a = document.createElement('a');
      a.href = '#' + h.id;
      a.textContent = h.textContent;
      a.dataset.id = h.id;
      a.className = 'lvl' + h.tagName.charAt(1);
      list.appendChild(a);
    });
    applySidebar();
    updateCurrent();
  }

  /** Applies the sidebar preference; a document without headings never shows it. */
  function applySidebar() {
    const show = sidebarWanted && !preview && headings.length > 0;
    document.body.classList.toggle('has-toc', show);
  }

  /** Marks the TOC entry of the heading currently at/above the top of the viewport. */
  let ticking = false;
  function updateCurrent() {
    ticking = false;
    let current = null;
    for (const h of headings) {
      if (h.getBoundingClientRect().top <= 24) current = h; else break;
    }
    if (!current && headings.length) current = headings[0];
    document.querySelectorAll('#toc-list a.current').forEach((a) => a.classList.remove('current'));
    if (current) {
      const a = Array.from($('toc-list').children).find((x) => x.dataset.id === current.id);
      if (a) { a.classList.add('current'); a.scrollIntoView({ block: 'nearest' }); }
    }
  }

  window.addEventListener('scroll', () => {
    if (!ticking) { ticking = true; setTimeout(updateCurrent, 40); }
  }, { passive: true });

  /** Link clicks: "#x" scrolls in place (the <base> tag would otherwise make it a navigation); the rest goes to native. */
  document.addEventListener('click', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    e.preventDefault();
    if (href.startsWith('#')) { scrollToId(href.slice(1)); return; }
    post({ type: 'link', href: href });
  });

  document.addEventListener('mouseover', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    const bar = $('linkbar');
    if (a) { bar.textContent = a.getAttribute('href').startsWith('#') ? a.getAttribute('href') : a.href.replace(/^file:\/\//, ''); bar.hidden = false; }
    else bar.hidden = true;
  });

  window.MarkDwain = window.MarkDwain || {};
  Object.assign(window.MarkDwain, {
    /**
     * First render. config: {markdown, sidebar, preview, truncated, anchor}.
     * preview=true is Quick Look: no sidebar, no native bridge.
     */
    boot: function (config) {
      preview = !!config.preview;
      sidebarWanted = !!config.sidebar;
      document.body.classList.toggle('preview', preview);
      $('truncated').hidden = !config.truncated;
      this.update(config.markdown, true);
      if (config.anchor) scrollToId(config.anchor);
    },

    /** Re-renders; keeps the scroll offset so live reload doesn't jump to the top. */
    update: function (markdown, initial) {
      const y = window.scrollY;
      $('content').innerHTML = window.MarkDwain.render(markdown);
      buildToc();
      if (!initial) window.scrollTo(0, y);
    },

    setSidebar: function (on) { sidebarWanted = !!on; applySidebar(); },
    setMissing: function (on) { $('missing').hidden = !on; },
    scrollToId: scrollToId
  });
})();
