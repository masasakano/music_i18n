// Auto-complete Model name with ID for merging
//
// Completion with AJAX.

// console.log('autocomplete_model_with_id_all.js is going to be read.');

import {autocompleteModelWithId} from './autocomplete_model_with_id.js';

const models = [
	["artist"],
	["music"],
	["channel_owner", "artist"]
];

models.forEach(
	(element) =>
		autocompleteModelWithId(element[0], element[1])
);

