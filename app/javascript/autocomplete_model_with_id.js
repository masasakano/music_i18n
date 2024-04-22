// Auto-complete Model name with ID for merging
//
// Completion with AJAX.

// console.log('autocomplete_model_with_id.js is going to be read.');

// model: Snake-case of the caller model (which should be used as an ID for <input>)
// to_model: model to auto-complete (either "artist" or "music"; so far only "artist" is supported)
export function autocompleteModelWithId(model, to_model=null){
	var prefix;
	if (!to_model) {
		prefix = model;
		to_model = model;
	} else {
		prefix = model + '_' + to_model;
	}
	var modelsel = "#" + $.escapeSelector(model+'_with_id');
  $(modelsel).autocomplete ({
    minLength: 2,
		delay: 500,
    source: function (req, resp) {
      $.ajax({
        //url: '/'+model+'s/merges/'+model+'_with_ids',  // or source: (?)
        url: '/'+to_model+'s/merges/'+to_model+'_with_ids',  // or source: (?)
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

