// Auto-complete Title for public view
//
// Completion with AJAX.

// console.log('autocomplete_title_public_load_all.js is going to be read.');

import {autocompleteTitlePublic} from './autocomplete_title_public.js';

const models = [
	["artist", "artists_grid_title_ja"],
	["artist", "harami_vids_grid_artists"],
	["artist", "musics_grid_artists"],
	["music",  "harami_vids_grid_musics"],
	["music",  "musics_grid_title_ja"]
];

models.forEach(
	(element) =>
		autocompleteTitlePublic(element[0], element[1])
);

