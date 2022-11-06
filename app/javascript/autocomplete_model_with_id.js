// Auto-complete Model name with ID for merging
//
// Completion with AJAX.

// console.log('autocomplete_model_with_id.js is going to be read.');

export function autocompleteModelWithId(model){
	var modelsel = "#" + $.escapeSelector(model+'_with_id');
  $(modelsel).autocomplete ({
    minLength: 2,
		delay: 500,
    source: function (req, resp) {
      $.ajax({
        url: '/'+model+'s/merges/'+model+'_with_ids',  // or source: (?)
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

