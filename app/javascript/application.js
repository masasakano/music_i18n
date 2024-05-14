// Entry point for the build script in your package.json
//import "@hotwired/turbo-rails"  // Rails 7 default
// But I change it so that JavaScript is activated in default every time a page is loaded; see
//   https://github.com/hotwired/turbo-rails#navigate-with-turbo-drive
//   https://stackoverflow.com/a/71140352/3577922
// Without this, the JavaScript is fired only when a page is reloaded.
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.drive = false
import "./controllers"
import * as bootstrap from "bootstrap"

//require("bootstrap/dist/js/bootstrap")
//import 'bootstrap'  // I think this causes popper-related error, if this is added "in addition to" 'bootstrap/dist/js/bootstrap.bundle'...
//import 'bootstrap/dist/js/bootstrap.bundle'  // not in Rails 7
//import 'popper.js/dist/esm/popper'  // not work in Rails 7
// import Popper from "popper.js"  // maybe?? see https://github.com/evanw/esbuild/issues/1686
//import './src/application.scss'  // according to https://gorails.com/forum/install-bootstrap-with-webpack-with-rails-6-beta  but is it necessary??
import Rails from "@rails/ujs"
////import Turbolinks from "turbolinks"  # Webpacker only.
import * as ActiveStorage from "@rails/activestorage"
//import "./channels"  // raises JS error in Rails 7

//// The following is from Rails 6.
Rails.start()
//Turbolinks.start()
ActiveStorage.start()

//// The following is I believe from Rails 6.0. The statements above are taken from Rails 6.1 default.
// require("@rails/ujs").start()
// require("turbolinks").start()
// require("@rails/activestorage").start()
// require("channels")

// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

// Added by User  // => In Rails 7, manually moved (and modified) to a new file: /app/javascript/jquery.js
import "./jquery"
import "jquery-ui-dist/jquery-ui"
//require("jquery")
//require("jquery_ujs")  // obsolete in Rails 6?
//require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
//require("jquery-ui")
//// According to https://qiita.com/kazutosato/items/c9dfa99d10411ced64b7 (most comprehensive guide about Rails 6/7 + jQuety + Bootstrap)
//// the following may be necessary (for global jQuery+Bootstrap).
//window.bootstrap = require("bootstrap")
//// Alternatively, to avoid global settings for jQuery+Bootstrap, write the following in every JS file instead (also delete in that case: import "./jquery"):
//import $ from 'jquery'
//import { Tooltip } from "bootstrap"
//$('[data-bs-toggle="tooltip"]').each((idx, elm) => {
//  new Tooltip(elm)
//})

//import * as toastr from 'toastr'  // maybe...
//import "toastr/toastr";  // maybe...
import toastr from 'toastr/toastr';  // https://stackoverflow.com/a/59347044/3577922
// @import "toastr/toastr";  // maybe...
// global.toastr = require("toastr")    // with webpacker
//import "./stylesheets/application.scss" // [ERROR] No loader is configured for ".scss" files // I *think* it is automatically loaded anyway...
// import "../stylesheets/application"  // with webpacker

//// According to https://github.com/d4be4st/toastr_rails
//= require toastr_rails

//// Following from config/webpack/environment.js
//environment.plugins.prepend('Provide',
//  new webpack.ProvidePlugin({
//    'window.jQuery': 'jquery/src/jquery',
//    toastr: 'toastr/toastr',
//    Rails: ['@rails/ujs'],
//    $: 'jquery/src/jquery',
//    jQuery: 'jquery/src/jquery',
//    jquery: 'jquery/src/jquery',
//    //Popper: ['popper.js', 'default'],
//    Popper: ['popper.js/dist/popper', 'default']
//  })
//)
//// cf. https://stackoverflow.com/a/58580434/3577922
//const aliasConfig = {
//    // 'jquery': 'jquery-ui-dist/external/jquery/jquery.js',  // A slightly different version (for testing?)
//    'jquery-ui': 'jquery-ui-dist/jquery-ui.js'  // yarn add jquery-ui-dist
//};
//environment.config.set('resolve.alias', aliasConfig);
//module.exports = environment

//= require data_grid/data_grid
//= require data_grid/grid_calendar/calendar
//= require data_grid/grid_calendar/calendar-setup
//= require data_grid/grid_calendar/lang/calendar-en

// import $ from 'jquery'  // required to use jquery-ui-dist in this file.

// User files
import "./manage_toastr.js"
import "./show_or_hide.js"
import "./autocomplete_artist.js"
import "./autocomplete_engage_artist.js"
import "./autocomplete_music_artist.js"
import "./autocomplete_model_with_id_all.js"
import "./dropdown_country2place.js"
import "./dropdown_country2place_all.js"
import "./modify_href_by_input.js"

