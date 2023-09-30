# == Schema Information
#
# Table name: model_summaries
#
#  id         :bigint           not null, primary key
#  modelname  :string           not null
#  note       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_model_summaries_on_modelname  (modelname) UNIQUE
#
class ModelSummary < BaseWithTranslation
  include Translatable

  # For the translations to be unique.
  MAIN_UNIQUE_COLS = %i(modelname)

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" from "The Beatles".  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = false

  validates_uniqueness_of :modelname, allow_nil: false
  validates :modelname, format: { with: /\A[A-Z][a-zA-Z0-9_]*/, message: " should be a Rails model name, starting with a capital letter" }

  # Validates translation immediately before it is added.
  #
  # Called by a validation in {Translation}
  #
  # @param record [Translation]
  # @return [Array] of Error messages, or empty Array if everything passes
  def validate_translation_callback(record)
    validate_translation_neither_title_nor_alt_exist(record)  # defined in BaseWithTranslation
  end
end
