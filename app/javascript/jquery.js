// To make jQuery available globally.
// c.f.: https://www.fastruby.io/blog/esbuild/webpacker/javascript/migrate-from-webpacker-to-esbuild.html
// c.f.: https://qiita.com/kazutosato/items/c9dfa99d10411ced64b7
// n.b., the contents of this file should not be directly written in application.js
//    in using it in conjunction with jquery-ui .  See for the background
//    https://youtu.be/ql-Ng6OeI-M?t=300 or a comment in https://stackoverflow.com/a/70925500/3577922
import jquery from "jquery"
window.jQuery = jquery
window.$ = jquery

