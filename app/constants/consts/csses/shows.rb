module Consts
  module Csses
    module Shows
      extend Freezable

      # Consts::Csses::Shows::ITEM_PREFIX
      ITEM_PREFIX  = (item_prefix="item_")
      ITEM_PID     = item_prefix+"pid"
      ITEM_WEIGHT  = item_prefix+"weight"
      ITEM_NOTE    = item_prefix+"note"
      ITEM_MEMO_EDITOR = item_prefix+"memo_editor"
      ITEM_UPDATED_AT  = item_prefix+"updated_at"
      ITEM_CREATED_AT  = item_prefix+"created_at"

      ###
      freeze_all
    end
  end
end

