// To make jQuery available globally.
// c.f.: https://www.fastruby.io/blog/esbuild/webpacker/javascript/migrate-from-webpacker-to-esbuild.html
// c.f.: https://qiita.com/kazutosato/items/c9dfa99d10411ced64b7
import jquery from "jquery"
window.jQuery = jquery
window.$ = jquery

