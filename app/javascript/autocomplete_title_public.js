// Auto-complete Title for public view
//
// Completion with AJAX.

// console.log('autocomplete_title_public.js is going to be read.');

// to_model: Snake-case of model to auto-complete (either "artist" or "music")
// cssid: directly specifies the CSS-ID for the <input> field to auto-complete.
//
// AJAX target algorithm is implemented in /app/controllers/base_auto_complete_titles_controller.rb
// whose core routine is found in /app/controllers/concerns/auto_complete_index.rb
// Some path-restriction algoritm is applied there.
//
// Example: autocompleteModelWithId("music", id="harami_vids_grid_musics")
export function autocompleteTitlePublic(to_model, cssid){
  $("#"+cssid).autocomplete ({
    minLength: 1,
		delay: 500,
    source: function (req, resp) {
      $.ajax({
        url: '/'+to_model+'s/ac_titles',  // or source: (?) // e.g., /musics/ac_titles
        type: 'GET',
        dataType: "json",
        data: {
					keyword: req.term,
					path: window.location.pathname
				},
        success: function(obj){
          resp(obj);
        },
        error: function(xhr, ts, err){ // if Ajax fails.
          resp(['']);
        }
      });
    }
  });
}

