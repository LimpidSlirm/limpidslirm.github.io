'use strict';

function pad(value) {
  return String(value).padStart(2, '0');
}

function buildNav(root, currentYear, currentMonth) {
  const posts = hexo.locals
    .get('posts')
    .toArray()
    .filter(post => !post.hide)
    .sort((a, b) => b.date.valueOf() - a.date.valueOf());

  if (!posts.length) return '';

  const groups = new Map();
  posts.forEach(post => {
    const year = post.date.year();
    const month = post.date.month() + 1;
    if (!groups.has(year)) groups.set(year, new Map());
    const months = groups.get(year);
    months.set(month, (months.get(month) || 0) + 1);
  });

  const url = path => (root + path).replace(/\/{2,}/g, '/');
  const parts = [];

  const indexActive = currentYear ? '' : ' current';
  parts.push(`<a class="archive-nav-all${indexActive}" href="${url('archives/')}">全部 ${posts.length}</a>`);

  for (const [year, months] of groups) {
    const yearActive = currentYear && String(year) === currentYear && !currentMonth ? ' current' : '';
    const monthLinks = [];
    for (const [month, count] of months) {
      const monthActive = String(year) === currentYear && pad(month) === currentMonth ? ' current' : '';
      monthLinks.push(
        `<a class="archive-nav-month${monthActive}" href="${url(`archives/${year}/${pad(month)}/`)}">` +
        `${month}月<span class="archive-nav-count">${count}</span></a>`
      );
    }
    parts.push(
      `<span class="archive-nav-group"><a class="archive-nav-year${yearActive}" href="${url(`archives/${year}/`)}">${year}</a>` +
      monthLinks.join('') +
      '</span>'
    );
  }

  return `<nav class="archive-nav" aria-label="Archive by year and month">${parts.join('')}</nav>`;
}

hexo.extend.filter.register('after_render:html', function(html, data) {
  const file = (data && data.path) || '';
  if (!/^archives\/.*index\.html$/.test(file)) return html;

  const match = file.match(/^archives\/(\d{4})\/?(\d{2})?\//);
  const currentYear = match ? match[1] : '';
  const currentMonth = match && match[2] ? match[2] : '';
  const root = hexo.config.root || '/';

  const nav = buildNav(root, currentYear, currentMonth);
  if (!nav) return html;

  const marker = '<div class="list-group">';
  const at = html.indexOf(marker);
  if (at === -1) return html;

  return html.slice(0, at) + nav + html.slice(at);
});
