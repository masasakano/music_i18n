class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # String representation of the Model for the previous page,
  # to which the website should be redirected to after an action like create.
  attr_accessor :prev_model_name 

  # ID of the Model corresponding to {#prev_model_name}
  attr_accessor :prev_model_id
end
