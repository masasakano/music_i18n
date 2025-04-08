// Modify a HREF value according to an input field value
//

modifyHrefByInput("pid_edit_harami_vid_with_ref", "href_edit_harami_vid_with_ref");

// console.log('modify_href_by_input is starting...');
//
// Example:
//   modifyHrefByInput("pid_edit_harami_vid_with_ref", "href_edit_harami_vid_with_ref")
export function modifyHrefByInput(input_id, href_id){
	const currentURL = new URL(window.location.href);
	const refid  = 'reference_harami_vid_id';

	// Function to update the URL based on input changes
  function updateURL() {
		// Get the path
    const newPath = currentURL.pathname.split('/').slice(0, -1).concat('new').join('/');
    const newUrl = new URL(newPath, currentURL.origin);

		// Get pID (from the DL list -- though well possible to get from the path)
    let localid = $('section#harami_vids_show_unique_parameters dd.item_pid').text().trim();

    // Get the value from the input tag with class "editing_url" using jQuery
    let formValue = $('#'+input_id).val();

		// Clear existing parameters
    newUrl.searchParams.delete(refid);
    newUrl.searchParams.delete('uri');

		// Set the 'reference_harami_vid_id' and 'uri' query parameters (if it has a value)
    newUrl.searchParams.set(refid, localid);
    if (formValue) {
      newUrl.searchParams.set('uri', formValue);
    }

		let constructedUrl = newUrl.toString();
    // console.log("Constructed URL:", constructedUrl);

		// Update the href attribute of the <a> tag
    $('#'+href_id).attr('href', constructedUrl);
	}

	$('#'+input_id).on('input propertychange paste', updateURL);
}

