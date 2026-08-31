import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Connects to data-controller="cascading-select-any"
  connect() {
  }

  update(event) {
    const { target, url, clear } = event.params
    const selectedId = event.target.value

    // 1. Wipes any extra downstream frames passed in `clear` (space-separated IDs)
		//    Specify 'cascading_select_any_clear_param: "places_select_frame"'
    if (clear) {
      clear.split(" ").forEach(frameId => {
        const frame = document.getElementById(frameId)
        if (frame) {
          frame.src = ""
          frame.innerHTML = ""
        }
      })
    }

    const targetFrame = document.getElementById(target)
    if (!targetFrame) return

    // 2. Interpolates selected ID into URL template (replaces :id or :any_name_id)
    if (selectedId) {
      const fetchUrl = url.replace(/:\w+_id|:id/, selectedId)

			// Listens for frame completion, then triggers 'change' on the new select element
      targetFrame.addEventListener("turbo:frame-load", () => {
        const childSelect = targetFrame.querySelector("select")
        if (childSelect && childSelect.value) {
          childSelect.dispatchEvent(new Event("change", { bubbles: true }))
        }
      }, { once: true })

      targetFrame.src = fetchUrl
    } else {
      targetFrame.src = ""
      targetFrame.innerHTML = ""
    }
  }
}
