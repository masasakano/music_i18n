module Translatable
  extend ActiveSupport::Concern

  included do
    has_many :translations, as: :translatable, dependent: :destroy
  end

  # Returns message if both title and alt_title are nulls
  #
  # @param trans [Translation]
  # @return [String, NilClass] String message if both are nulls; otherwise nil
  def msg_validate_double_nulls(trans)
    return if trans.title || trans.alt_title
    "Neither title nor alt_title is significant for #{trans.class.name} for #{self.class.name}."
  end
end
