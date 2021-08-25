// Auto-complete an Artist name

// console.log('dropdown JS file is going to be read.');

require("jquery")
require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
import $ from 'jquery'

import {autocompleteArtist} from './autocomplete_artist.js';

var model = 'music';
$(autocompleteArtist(model));

