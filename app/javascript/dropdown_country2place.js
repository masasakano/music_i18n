// Dropdown menu handling for Country-Prefecture-Place for HaramiVid and else
//

// console.log('dropdown JS file is going to be read.');

//require("jquery")
//require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
import $ from 'jquery'

export function dropdownCountry2Place(model){
	// Dynamic dropdown menu - Country-Prefecture
	var contsel = "#" + $.escapeSelector(model+'_place.prefecture_id.country_id');
	var prefsel = "#" + $.escapeSelector(model+'_place.prefecture_id');
	var prefsel_nil = ($(prefsel).val() === "");
	if (prefsel_nil) {
  	$(prefsel).parent().hide();
	}
	ddCountryPrefecture(model, !prefsel_nil);  // For the initial load only.
	$(contsel).change(function(){ddCountryPrefecture(model)});

	var placesel = "#" + $.escapeSelector(model+'_place');
	var placesel_nil = ($(placesel).val() === "");
	if (placesel_nil) {
  	$(placesel).parent().hide();
	}
	ddPrefecturePlace(model, !placesel_nil);  // For the initial load only.
	$(prefsel).change(function(){ddPrefecturePlace(model)});
}

function ddCountryPrefecture(model, selected = false){
	// Every time change fires, selected should become false (Default).
	// For initial load, selected may remain true.
	var placesel = "#" + $.escapeSelector(model+'_place');
  $(placesel).hide();  // Hide Place whenever Country changes.
  $(placesel).parent().hide();
  var prefsel = "#" + $.escapeSelector(model+'_place.prefecture_id');
  var contsel = "#" + $.escapeSelector(model+'_place.prefecture_id.country_id');
  var country = $.escapeSelector($(contsel + ' :selected').text());
  var prefs = $(prefsel).html();
  var options = $(prefs).filter("optgroup[label='" + country + "']").html();
  if (options) {
    $(prefsel).parent().show();
    $(prefsel).show();
    $(prefsel + " optgroup").hide();
    $(prefsel + " optgroup[label='" + country + "']").show();
		if (!selected) {
			$(prefsel).find('option:selected').prop("selected", false);
		}
  } else {
    $(prefsel).hide();
    $(prefsel).parent().hide();
  }
}

function ddPrefecturePlace(model, selected = false){
	// Every time change fires, selected should become false (Default).
	// For initial load, selected may remain true.
	var contsel = "#" + $.escapeSelector(model+'_place.prefecture_id.country_id');
  var country = $.escapeSelector($(contsel + ' :selected').text());
  var placesel = "#" + $.escapeSelector(model+'_place');
  var prefsel = "#" + $.escapeSelector(model+'_place.prefecture_id');
  var prefecture = $.escapeSelector($(prefsel + ' :selected').text());
  var places = $(placesel).html();
  var strlabel = prefecture + "/" + country;
  var options = $(places).filter("optgroup[label='" + strlabel + "']").html();
  if (options) {
    $(placesel).parent().show();
    $(placesel).show();
    $(placesel + " optgroup").hide();
    $(placesel + " optgroup[label='" + strlabel + "']").show();
		if (!selected) {
			$(placesel).find('option:selected').prop("selected", false);
		}
  } else {
    $(placesel).hide();
    $(placesel).parent().hide();
  }
}

// console.log('dropdown JS file was read.');

//  var states = $("#harami_vid_place\\.prefecture_id\\.country_id").html();
//  console.log(states);
// $( "#myDiv" ).css( "border", "3px solid red" ); // Even this does not work.

