// Show or hide a part of a HTML
//
// The content that has class="show_or_hide" will be affected.
// The link as follows should be put. For example, if it is hidden when first loaded:
//    <div class="show_or_hide" style="display: none;">
//    (……<a id="Link_show_or_hide" title="Show or hide" href="#">Show</a>)
// along with
//    <%= javascript_pack_tag 'show_or_hide' %>

// console.log('a JS file is going to be read.');

require("jquery")
require("jquery-ui-dist/jquery-ui")  // AFTER: yarn add jquery-ui-dist
import $ from 'jquery'

$('#Link_show_or_hide').click(function(){
  if ($('#Link_show_or_hide').text() == "Hide") {
    $('.show_or_hide').hide();
    $('#Link_show_or_hide').html("Show");
  } else {
    $('.show_or_hide').show();
    $('#Link_show_or_hide').html("Hide");
  }
	return false;
});

