'use strict';

const fs = require('fs');
const path = require('path');

hexo.extend.generator.register('readme', function () {
  const source = path.join(hexo.base_dir, 'README.md');
  if (!fs.existsSync(source)) return [];
  return {
    path: 'README.md',
    data: () => fs.readFileSync(source)
  };
});
