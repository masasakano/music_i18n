// Apply toastr from the script tag inside HTML head
//
// For toastr, see <https://github.com/CodeSeven/toastr>
//
// Originally, I meant to use it to replace the Rails standard "notice" and "alert".
// However, most of the standard error messages of Rails should not disappear.
// Toast(r) is more appropriate for very short and unimportant notice messages.
//
// Therefore, I have abandoned the idea.
// Now, instead of replacing the standard notice/alert, I have introduced
// new CSS classes like "toasst_success" for div and p, which can be used instead.
//
// Note that if you use it in conjunction with Bootstrap (or at least its custom one),
// you have to find a way.  The box is transparent; therefore if the original div box
// is transparent, the overlayed toastr box becomes more opaque.

import toastr from 'toastr/toastr';  // https://stackoverflow.com/a/59347044/3577922

toastr.options.closeButton = true;
//toastr.options.timeOut = 0;  // [msec]?
toastr.options.extendedTimeOut = 0;  // While the mouse pointer is on it, it will never disappear.
//toastr.options.progressBar = true; // ProgressBar before the pop-up disappaers.
//toastr.options.positionClass = "toast-top-full-width"; // did not work for some reason, though it is described in https://stackoverflow.com/questions/28057622/how-to-adjust-toaster-popup-width  (nb., the div block appears at the bottom, whereas the main toastr block appears at the specified place in the HTML.  So, chances are, this way of use, i.e., replacing a block in the current HTML, may not be appropriate!  The standard way is to write a toastr script-tag directry in the middle of the HTML.)

manage_toastr();

export function manage_toastr(){
	//const levels = ["alert-info", "notice", "alert-success", "alert-warning", "alert-danger", "error", "alert"]; /* c.f., https://getbootstrap.com/docs/4.0/components/alerts/ */
	const levels = ["toast_info", "toast_success", "toast_warning", "toast_error"];
	const level2method = {
    "toast_info":    "info",
    "toast_success": "success",
    "toast_warning": "warning",
    "toast_error":   "error",
    //"alert-info":    "info",
    //"alert-success": "success",
    //notice:          "success",
    //"alert-warning": "warning",
    //"alert-danger":  "error",
    //error:           "error",
    //alert:           "error",
  };

	for (const eal of levels) {  // ES6 grammar.
		var jeal, htmlString;
		//// CSS-ID
		//jeal = 'p#'+eal;
		//htmlString = $(jeal).html();
		//if (htmlString){
		//	$(jeal).html( toastr[level2method[eal]](htmlString, {closeButton: true}) );
		//}

		// CSS-class
		if (eal != "alert"){
			// "alert" is a standard CSS for Bootstrap, encompassing all of them. So, p.alert is ignored.
			jeal = `p.${eal}, div.${eal}`;  // ES6
			htmlString = $(jeal).html();
		  if (! htmlString){ continue; }
			$(jeal).html( toastr[level2method[eal]](htmlString) );
			// htmlOuterString = $(jeal).prop('outerHTML')
			//$(jeal).replaceWith(toastr[level2method[eal]](htmlOuterString, {positionClass: "toast-top-full-width"}) );
		}
	}
}

