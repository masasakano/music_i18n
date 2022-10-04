// Dropdown menu for HaramiVid
//
// 2 change() functions are defined.

// console.log('dropdown JS file is going to be read.');

import {dropdownCountry2Place} from './dropdown_country2place.js';

var model = 'harami_vid';
$(dropdownCountry2Place(model));
$(function(){
	// jquery-ui-dist
	const availableCities = ['foo', 'food', 'four'];
	$('#'+model+'_artist').autocomplete( { source: availableCities } );  // autocomplete test
})

// console.log('dropdown JS file was read.');

//  var states = $("#harami_vid_place\\.prefecture_id\\.country_id").html();
//  console.log(states);
// $( "#myDiv" ).css( "border", "3px solid red" ); // Even this does not work.

