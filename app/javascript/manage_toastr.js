// Apply toastr from the script tag inside HTML head
//
// Basically, when class of 
//
// For toastr, see <https://github.com/CodeSeven/toastr>
export function manage_toastr(){
	const levels = ["alert-info", "notice", "alert-success", "alert-warning", "alert-danger", "error", "alert"]; /* c.f., https://getbootstrap.com/docs/4.0/components/alerts/ */
	const level2method = {
		"alert-info":    "success",
		"alert-success": "success",
		notice:          "success",
		"alert-warning": "warning",
		"alert-danger":  "error",
		error:           "error",
		alert:           "error",
	};

	for (const eal of levels) {  // ES6 grammar.
		var jeal = 'p#'+eal;
		$(jeal).replaceWith( toastr[level2method[jeal]]($(eal).html()) );
		if (eal != "alert"){
			// "alert" is a standard CSS for Bootstrap, encompassing all of them. So, p.alert is ignored.
			jeal = sprintf('p.%s, div,%s', eal, eal);
			$(jeal).replaceWith( toastr[level2method[jeal]]($(eal).html()) );
		}
	}
}

