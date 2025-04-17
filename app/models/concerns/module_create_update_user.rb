# Common module for models that have create_user and update_user attributes
#
# @example
#    # handles create_user, update_user attributes
#    include ModuleCreateUpdateUser
#
module ModuleCreateUpdateUser
  extend ActiveSupport::Concern

  include ModuleWhodunnit # for set_create_user, set_update_user

  included do
    before_create :set_create_user  # This always sets non-nil weight. defined in /app/models/concerns/module_whodunnit.rb
    before_save   :set_update_user  # defined in /app/models/concerns/module_whodunnit.rb

    belongs_to :create_user, class_name: "User", foreign_key: "create_user_id", optional: true
    belongs_to :update_user, class_name: "User", foreign_key: "update_user_id", required: false
  end

end

