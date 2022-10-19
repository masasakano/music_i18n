class Users::EditRolesController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  #load_and_authorize_resource :user
  load_and_authorize_resource :user

  def update
    # params == #<ActionController::Parameters {"_method"=>"patch", "authenticity_token"=>"...", "role_harami"=>"harami_editor", "role_translation"=>"translation_helper", "role_general_ja"=>"none", "reset"=>"Reset (Start Over)", "commit"=>"Update Roles", "controller"=>"users/edit_roles", "action"=>"update", "id"=>"79"} permitted: false>  # it may also contain "role_ROOT"

    raise if !@user # non-existent user - should never happen.

    hsprm = user_edit_role_params
    # update:#<ActionController::Parameters {"role_ROOT"=>"sysadmin", "role_harami"=>"harami_editor", "role_translation"=>"translation_helper", "role_general_ja"=>"none"} permitted: true>

##print "DEBUG:update:";p params
#print "DEBUG:update:";p hsprm
#raise
#print "DEBUG:user:";p @user
    n_changes = nil
    RoleCategory.all.each do |rolec|
      prmkey = User::ROLE_FORM_RADIO_PREFIX + rolec.mname
      next if !params[prmkey]
      next if !current_user.qualified_as?(rolec.lowest_role)
      next if !current_user.superior_to?(@user, rolec) && current_user != @user

#      highest_role = @user.highest_role_in(rolec)
#      if highest_role && !current_user.qualified_as?(highest_role)
#        # @user is in a higher rank than the current_user in the RoleCategory;
#        # hence current_user is NOT allowed to manage.
#        msg = sprintf("User (ID=%d) tries to demote another user (ID=%d), who is senior in RoleCategory=(%s(ID=%d)), which should never happen from the web-interface.", current_user.id, @user.id, rolec.mname, rolec.id)
#        logger.warn msg
#warn msg
#        next
#      end

#print "DEBUG:be4:";p @user.roles.pluck(:uname)
      n_changes ||= 0
      all_roles = @user.roles_in(rolec)
#print "DEBUG:process:";p [@user.email, rolec.mname, all_roles.pluck(:uname)]

      role_id = hsprm[prmkey].to_i
      if role_id > 0
        role_dest = Role.find role_id
        next if all_roles.first == role_dest  # No change
        if ! current_user.qualified_as?(role_dest)
          msg = sprintf("User (ID=%d) tries to assign a role (uname=%s) of RoleCategory (mname=%s) to user (ID=%d), for which the user is not qualified for, and this should never happen from the web-interface.", current_user.id, role_dest.uname, rolec.mname, @user.id)
          logger.warn msg
          next
        end
      end

      n_changes += 1

      @user.roles << role_dest if role_id > 0

#print "DEBUG:all:";p all_roles
      # Destroy all the roles in the specified RoleCategory.
      # In fact User should have at most 1 Role; however, since DB allows multiple ones,
      # this method makes sure all of the are destroyed.
      all_roles && all_roles.each do |er|
        @user.roles.delete er if er != role_dest && (current_user.superior_to?(er) || (current_user == @user && current_user.qualified_as?(er)))
      end
#print "DEBUG:user:";p @user.email
    end

    respond_to do |format|
      if n_changes
        msg = sprintf '%s for User=(%s) %s successfully updated.', view_context.pluralize(n_changes, 'Role'), @user.display_name, ((n_changes==1) ? 'was' : 'were')
        hsmsg = { notice: msg }
      else
        msg = 'You are not allowed to perform the operation.'
        hsmsg = { alert: msg }
      end
      format.html { redirect_to @user, **hsmsg }
      format.json { render :show, status: :ok, location: @sex }
    end
  end

  private
    def set_user
      @user = User.find(params[:id]) if params[:id]
    end

    # Only allow a list of trusted parameters through. create only (NOT update)
    def user_edit_role_params
      params.permit(*form_params)
    end

    # @return [Array<String>] All the role-related keys for params()
    def form_params
      RoleCategory.all.map{|i| User::ROLE_FORM_RADIO_PREFIX + i.mname}
    end
end

