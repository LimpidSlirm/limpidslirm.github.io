'use strict';

const pagination = require('hexo-pagination');

hexo.extend.generator.register('study-notes-archive', function(locals) {
  const posts = locals.hide_posts
    .filter(post => post.categories && post.categories.find({ name: 'Study Notes' }).length)
    .sort('-date');

  if (!posts.length) return [];

  const categories = locals.categories.data;
  const categoryIndex = categories.findIndex(category => category.name === 'Study Notes');
  const studyNotesCategory = {
    name: 'Study Notes',
    posts,
    length: posts.length
  };
  if (categoryIndex === -1) {
    categories.push(studyNotesCategory);
  } else {
    categories[categoryIndex] = studyNotesCategory;
  }

  return pagination('categories/Study-Notes/', posts, {
    perPage: posts.length,
    layout: 'category',
    format: 'page/%d/',
    data: {
      category: 'Study Notes'
    }
  });
});
