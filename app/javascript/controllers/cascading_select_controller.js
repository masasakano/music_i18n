import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "goal"] // change event in "input" prompts update(), which will replace the selection list in "goal"
  static values = { 
    urlTemplate: String, // <= eg. "/event_groups/:event_group_id/events", where ":event_group_id" will be replaced below.
    selectName: String,  // <= eg. "event_item[event_id]"
    selected: String,    // <= eg. @record.event_id (maybe nil)
    required: Boolean // Accepts true/false
  }

  update() {
    let path = this.urlTemplateValue
    const queryParams = new URLSearchParams()
    let missingRequiredPathParam = false

    this.inputTargets.forEach(input => {
      const name = input.dataset.paramName || input.name
      const value = input.value
      const placeholder = `:${name}`

      if (path.includes(placeholder)) {
        if (value) {
          // ID in the requesting Path set.
          path = path.replace(placeholder, encodeURIComponent(value))
        } else {
          missingRequiredPathParam = true
        }
      } else if (value) {
        // Else, filtering parameters are passed as the URL-query parameters
        queryParams.append(name, value)
      }
    })

    // While no parent element is selected, the SELECT in the goal is invalidated with no choice for SELECT
    if (missingRequiredPathParam) {
      this.goalTarget.src = ""
      this.goalTarget.innerHTML = `<select class="form-select" disabled><option>Select parent option first...</option></select>`
      return
    }

    const url = new URL(path, window.location.origin)
    queryParams.forEach((v, k) => url.searchParams.set(k, v))

    // Appends basic parameters to the query parameters so that they will be handled in the Controller and/or ERB
    if (this.hasSelectNameValue) {
      url.searchParams.set("select_name", this.selectNameValue)
    }

    if (this.hasSelectedValue) {
      url.searchParams.set("selected", this.selectedValue)
    }

    if (this.hasRequiredValue) {
      url.searchParams.set("required", this.requiredValue)
    }

    // Overwrites the "src" attribute of the tag with "goal",
    // where the tag is "turbo-frame" so that Turbo will immediately respond to the change
    // and send the GET AJAX request to the "src" path on the server.
    this.goalTarget.src = url.toString()
  }
}

