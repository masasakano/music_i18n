module Consts
  module Csses
    module Layouts  # Consts::Csses::Layouts::
      extend Freezable

      TURBO_MANAGED          = "turbo_managed" # Affected part by Turbo (like a Table row)
      TURBO_ACTION           = "turbo_action"  # Contains Turbo actions (like a cell with Turbo Destroy/Edit-button)

      FORM_INPUTS            = "form_inputs"  # Default in Rails scaffolding for inputs in forms
      FORM_ACTION_CONTAINER  = "form-actions" # Default in Rails scaffolding for <div> for submission buttons

      ACTION_LINKS_CONTAINER = "actions"   # for any of the following or submit_tag (for <td> <div> etc)
      NEW_LINK               = "new_link"            # for link or button
      EDIT_LINK_CONTAINER    = "edit_link_container" # for Table <td> or <div> or <span> or <p>
      EDIT_LINK_PRIMARY      = "edit_link_primary"   # for the primary link or button for Edit of the main contents
      EDIT_LINK              = "edit_link"           # for link or button; n.b., for naming, I suggest EDIT_ANCHOR for <a> and EDIT_BUTTON for <button>
      DESTROY_LINK_CONTAINER = "destroy_link_container"
      DESTROY_LINK           = "destroy_link"

      ADD_TRANSLATION_ANCHOR = "add_translation_anchor" # Button or button-like link in Translation tables
      ###
      freeze_all
    end
  end
end

