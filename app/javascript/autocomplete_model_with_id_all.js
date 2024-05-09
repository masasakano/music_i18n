// Auto-complete Model name with ID for merging
//
// Completion with AJAX.

// console.log('autocomplete_model_with_id_all.js is going to be read.');

import {autocompleteModelWithId} from './autocomplete_model_with_id.js';

const models = [
	["artist"],
	["music"],
	["channel_owner", "artist"],
  ["harami_vid",    "music",  "harami_vid_music_name"],
  ["harami_vid",    "artist", "harami_vid_artist_name"],
  ["harami_vid",    "artist",	"harami_vid_artist_name_collab"]
];

models.forEach(
	(element) =>
		autocompleteModelWithId(element[0], element[1], element[2])
);

