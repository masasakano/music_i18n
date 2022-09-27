// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"

//require("bootstrap/dist/js/bootstrap")
//import 'bootstrap'  // I think this causes popper-related error, if this is added "in addition to" 'bootstrap/dist/js/bootstrap.bundle'...
//import 'bootstrap/dist/js/bootstrap.bundle'  // not in Rails 7
import 'popper.js/dist/esm/popper'
//import './src/application.scss'  // according to https://gorails.com/forum/install-bootstrap-with-webpack-with-rails-6-beta  but is it necessary??
//import Rails from "@rails/ujs"
//import Turbolinks from "turbolinks"
//import * as ActiveStorage from "@rails/activestorage"
//import "channels"

//// The following is from Rails 6.
//Rails.start()
//Turbolinks.start()
//ActiveStorage.start()

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

// Added by User
require("jquery")
//require("jquery_ujs")  // obsolete in Rails 6?
require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
//require("jquery-ui")

global.toastr = require("toastr")
import "../stylesheets/application"

//= require data_grid/data_grid
//= require data_grid/grid_calendar/calendar
//= require data_grid/grid_calendar/calendar-setup
//= require data_grid/grid_calendar/lang/calendar-en

// import $ from 'jquery'  // required to use jquery-ui-dist in this file.

