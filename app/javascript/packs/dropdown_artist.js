// Dropdown menu for Artist
//
// change() functions are defined.

// console.log('dropdown JS file is going to be read.');

require("jquery")
require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
import $ from 'jquery'

import {dropdownCountry2Place} from './dropdown_country2place.js';

var model = 'artist';
$(dropdownCountry2Place(model));

