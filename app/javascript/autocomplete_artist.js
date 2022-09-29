// Auto-complete an Artist name
//
// Client side so far

// console.log('dropdown JS file is going to be read.');

//require("jquery")
//require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
import $ from 'jquery'

export function autocompleteArtist(model){
  $(function(){
  	// jquery-ui-dist
  	//const availableCities = ['foo', 'food', 'four'];
    $('#'+model+'_artist_name').autocomplete( { source: $('#suggestions').data('items') } );  // autocomplete in the client side
  })
}

