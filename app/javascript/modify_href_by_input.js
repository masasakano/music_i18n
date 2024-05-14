// Modify a HREF value according to an input field value
//

modifyHrefByInput("pid_edit_harami_vid_with_ref", "href_edit_harami_vid_with_ref");

// console.log('modify_href_by_input is starting...');
//
// Example:
//   modifyHrefByInput("pid_edit_harami_vid_with_ref", "href_edit_harami_vid_with_ref")
export function modifyHrefByInput(input_id, href_id){
	$('#'+input_id).on('input propertychange paste', function() {
		var localid = $("section#harami_vids_show_unique_parameters dd.item_pid").text().replace(/\s/gm, '');
		$('#'+href_id).attr("href", $('#'+input_id).val()+"/edit?reference_harami_vid_id="+localid);
	});
}

