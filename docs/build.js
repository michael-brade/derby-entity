var fs = require('fs');
var path = require('path');
var exorcist = require('exorcist');
var browserify = require('browserify');

var root = path.join(__dirname, 'js');

browserify({debug: true})
  .add(path.join(__dirname, './derby-standalone.js'))
  .bundle()
  .pipe(exorcist(path.join(root, 'derby-standalone.map.json')))
  .pipe(fs.createWriteStream(path.join(root, 'derby-standalone.js')));
