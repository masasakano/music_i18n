module HaramiMusicI18n
  module Urls
    class NotAnchorableError < StandardError  # HaramiMusicI18n::Urls::NotAnchorableError
      ## Error in accessing ActiveRecord class that is not "anchorable", i.e., not in the polymorphic relation with Anchoring.
    end
  end
end
