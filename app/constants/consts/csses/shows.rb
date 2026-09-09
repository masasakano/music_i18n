module Consts
  module Csses
    module Shows
      extend Freezable

      # Consts::Csses::Shows::ITEM_PREFIX
      ITEM_PREFIX  = (item_prefix="item_")
      ITEM_MULTIPLE    = item_prefix+"multiple"

      ITEM_PID     = item_prefix+"pid"
      ITEM_WEIGHT  = item_prefix+"weight"
      ITEM_NOTE    = item_prefix+"note"
      ITEM_MEMO_EDITOR = item_prefix+"memo_editor"
      ITEM_UPDATED_AT  = item_prefix+"updated_at"
      ITEM_CREATED_AT  = item_prefix+"created_at"

      ITEM_TITLE       = item_prefix+"title"
      ITEM_MUSIC       = item_prefix+"music"
      ITEM_ARTIST      = item_prefix+"artist"
      ITEM_PLACE       = item_prefix+"place"
      ITEM_CHANNEL     = item_prefix+"channel"
      ITEM_EVENT_ITEM  = item_prefix+"event_item"
      ###
      freeze_all
    end
  end
end

