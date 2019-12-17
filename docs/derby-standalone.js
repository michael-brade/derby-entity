// Includes full template and expression parsing in bundle
var parsing = require('derby/parsing');
var path = require('path');
var DerbyStandalone = require('derby/lib/DerbyStandalone');
var Router = require('derby-router')
var derby = new DerbyStandalone();
var App = derby.App;

window.jQuery = window.$ = require('jquery');

global.derby = module.exports = derby;

derby.Router = Router;

App.prototype.getTemplate = function(filename) {
    var el = document.getElementById(filename);
    if (el) return el;

    var result = undefined;

    if (filename[0] === '/')
        filename = '.' + filename;

    $.ajax({
        method: 'GET',
        url: filename,
        async: false
    })
    .done(function(response) {
        result = response;
    })
    .fail(function() { })

    return result;
};

App.prototype.loadViews = function(filename, namespace) {
  var resolved = this._resolveTemplate(filename);
  if (!resolved) {
    throw new Error('Cannot find template "' + filename + '"');
  }
  this._registerTemplate(resolved.template, namespace, resolved.filename);
};

App.prototype._registerTemplate = function(template, namespace, filename) {
  var file = typeof template === 'string' ? template : template.innerHTML;
  var app = this;
  function onImport(attrs) {
    var dir = path.dirname(filename);
    var sourceFilename = path.resolve(dir, attrs.src);
    var resolved = app._resolveTemplate(sourceFilename);
    if (!resolved) {
      throw new Error('Cannot find template "' + attrs.src + '" from "' + filename + '"');
    }
    importNamespace = parsing.getImportNamespace(namespace, attrs, resolved.filename);
    app._registerTemplate(resolved.template, importNamespace, resolved.filename);
  }
  var items = parsing.parseViews(file, namespace, filename, onImport);
  parsing.registerParsedViews(this, items);
};

App.prototype._resolveTemplate = function(filename) {
  var resolved;
  resolved = this._attemptResolveTemplate(filename);
  if (resolved) return resolved;
  resolved = this._attemptResolveTemplate(filename + '.html');
  if (resolved) return resolved;
  resolved = this._attemptResolveTemplate(filename + '/index');
  if (resolved) return resolved;
  resolved = this._attemptResolveTemplate(filename + '/index.html');
  return resolved;
};

App.prototype._attemptResolveTemplate = function(filename) {
  var template = this.getTemplate(filename);
  if (template) return {template: template, filename: filename};
};
