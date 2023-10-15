
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # String representation of the Model for the previous page,
  # to which the website should be redirected to after an action like create.
  attr_accessor :prev_model_name 

  # ID of the Model corresponding to {#prev_model_name}
  attr_accessor :prev_model_id

  # Returns true if the record has been destroyed on the DB.
  def db_destroyed?
    !self.class.exists? id
  end
end
require "reverse_sql_order"   # A user monkey patch to modify reverse_sql_order() in ActiveRecord::QueryMethods::WhereChain
