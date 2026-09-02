module Consts
  module HtmlIds
    extend Freezable

    # Consts::HtmlIds::
    FLASH = "global_flash_messages"
    FORM_MAIN  =  "form_main"  # Main/primary form in :edit
    MAIN_LINK_EDIT_MERGE_DESTROY = "main_link_edit_merge_destroy"

    HARAMI_VIDS_SHOW_MUSICS   = "harami_vids_show_musics"    # for section
    HARAMI_VIDS_HVMA_CSV_FORM = "harami_vids_hvma_csv_form"  # for sub-section
    HARAMI_VIDS_SHOW_OTHER_HARAMI_VIDS = "harami_vids_show_other_harami_vids" # for section

    TURBO_EVENTS_SELECT_FRAME = "events_select_frame"

    ###
    freeze_all
  end
end

