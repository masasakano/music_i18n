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
  # For the translations to be unique (required by BaseWithTranslation).
  MAIN_UNIQUE_COLS = %i(modelname)

  # Each subclass of {BaseWithTranslation} should define this constant; if this is true,
  # the definite article in each {Translation} is moved to the tail when saved in the DB,
  # such as "Beatles, The" when "The Beatles" is passed.  If the translated title
  # consists of a word or few words, as opposed to a sentence or longer,
  # this constant should be true (for example, {Music#title}).
  ARTICLE_TO_TAIL = false

  # Optional constant for a subclass of {BaseWithTranslation} to define the scope
  # of required uniqueness of title and alt_title.
  #TRANSLATION_UNIQUE_SCOPES = :default

  validates_uniqueness_of :modelname, allow_nil: false
  validates :modelname, format: { with: /\A[A-Z][a-zA-Z0-9_]*/, message: " should be a Rails model name, starting with a capital letter" }

end
