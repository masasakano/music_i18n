module Translatable
  extend ActiveSupport::Concern

  included do
    has_many :translations, as: :translatable, dependent: :destroy
  end

  # Returns message if both title and alt_title are nulls
  #
  # @param record [Translation]
  # @return [String, NilClass] String if both are nulls, otherwise nil
  def msg_validate_double_nulls(record)
    return if record.title || record.alt_title
    "Neither title nor alt_title is significant for #{record.class.name} for #{self.class.name}."
  end
end
