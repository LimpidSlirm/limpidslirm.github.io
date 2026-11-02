'use strict';

// 支持在 front-matter 中用 `index_img_position: right` 把首页卡片的头图移到右侧
// Supports moving the index card cover to the right via `index_img_position: right`

const CARD_CLASS = 'row mx-auto index-card';
const CARD_TAG = `<div class="${CARD_CLASS}">`;

function postHref(post) {
  const root = (hexo.config.root || '/').replace(/\/?$/, '/');
  const path = String(post.path || '').replace(/^\//, '');
  return `href="${root}${path}"`;
}

hexo.extend.filter.register('after_render:html', function(html) {
  if (!html.includes(CARD_TAG)) return html;

  const hrefs = hexo.locals.get('posts')
    .filter(post => post.index_img && post.index_img_position === 'right')
    .map(postHref);

  if (!hrefs.length) return html;

  const parts = html.split(CARD_TAG);
  let result = parts[0];
  for (let i = 1; i < parts.length; i++) {
    const chunk = parts[i];
    const moveRight = chunk.includes('index-img') && hrefs.some(href => chunk.includes(href));
    result += (moveRight ? `<div class="${CARD_CLASS} index-card-right">` : CARD_TAG) + chunk;
  }
  return result;
});
