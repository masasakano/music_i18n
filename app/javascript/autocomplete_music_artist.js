// Auto-complete an Artist name

// console.log('dropdown JS file is going to be read.');

import {autocompleteArtist} from './autocomplete_artist.js';

var model = 'music';
$(autocompleteArtist(model));

var model2 = 'harami_vid';
$(autocompleteArtist(model2));
