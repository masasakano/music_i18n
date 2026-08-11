import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "frame"]
  static values = { 
    urlTemplate: String,
    selectName: String,
    selected: String,
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
          path = path.replace(placeholder, encodeURIComponent(value))
        } else {
          missingRequiredPathParam = true
        }
      } else if (value) {
        queryParams.append(name, value)
      }
    })

    if (missingRequiredPathParam) {
      this.frameTarget.src = ""
      this.frameTarget.innerHTML = `<select class="form-select" disabled><option>Select parent option first...</option></select>`
      return
    }

    const url = new URL(path, window.location.origin)
    queryParams.forEach((v, k) => url.searchParams.set(k, v))

    if (this.hasSelectNameValue) {
      url.searchParams.set("select_name", this.selectNameValue)
    }

    if (this.hasSelectedValue) {
      url.searchParams.set("selected", this.selectedValue)
    }

    // Send required status to the endpoint
    if (this.hasRequiredValue) {
      url.searchParams.set("required", this.requiredValue)
    }

    this.frameTarget.src = url.toString()
  }
}

