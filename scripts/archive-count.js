'use strict';

// Fluid 的归档列表用的是 site.posts.length，年/月页也会显示全站总数。
// 这里在渲染完成后把它换成当前页实际列出的篇数。
hexo.extend.filter.register('after_render:html', function(html, data) {
  const file = (data && data.path) || '';
  if (!/^archives\/.*index\.html$/.test(file)) return html;

  const count = (html.match(/class="list-group-item list-group-item-action"/g) || []).length;
  if (!count) return html;

  let out = html.replace(/(<p class="h4">)\d+/, `$1${count}`);
  if (count === 1) out = out.replace('posts in total', 'post in total');
  return out;
});
