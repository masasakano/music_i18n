import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "element"]
  static values = { expected: String }

  connect() {
    this.toggle()
  }

  toggle() {
    // Finds the radio button currently checked
    const checkedTrigger = this.triggerTargets.find(input => input.checked)
    const shouldShow = checkedTrigger && String(checkedTrigger.value) === String(this.expectedValue)

    // Toggle Bootstrap 'd-none' class to hide the element
    this.elementTargets.forEach(element => {
      element.classList.toggle("d-none", !shouldShow)
    })
  }
}

