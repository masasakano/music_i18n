# -*- coding: utf-8 -*-

class UserRoleAssocController < ApplicationController
  #load_and_authorize_resource :through => :current_user
  #load_and_authorize_resource :user #, only: [:update]
  #load_and_authorize_resource :user_role_assoc, :through => :user
  before_action :set_user, only: [:update]
  #load_and_authorize_resource :user_role_assoc, class: 'User', :parent => false #, :through => :user
  ##load_and_authorize_resource param_method: :set_user
  ##skip_authorize_resource :only => [:update]

  # Update {Role}s
  #
  # PATCH/PUT /user_role_assoc/1
  # PATCH/PUT /user_role_assoc/1.json
  def update
    #authorize! :update, (@user.user_role_assocs.first || User.roots[0].user_role_assocs.first), :message => "Unable to access this update of UserRoleAssoc..."  ###### forces to get something existing (but if it is for sysadmin/root, even a moderator cannnot access)...
    authorize! :update, (@user.user_role_assocs.first || (Role[:moderator, :translation] || User.roots[0]).user_role_assocs.first), :message => "Unable to access this update of UserRoleAssoc..."  ###### forces to get something existing (so Editor cannnot access but moderator can)...
    tgt_role_unames = @user.roles.map{|i| (i.uname || i.name)}
    alert = nil
    ActiveRecord::Base.transaction do
      RoleCategory.tree(force_update: true).each do |ea_rct|
      #RoleCategory.tree.each do |ea_rct|
        eak = User::ROLE_FORM_RADIO_PREFIX+ea_rct.name
        next if !params[eak].present? || params[eak].blank?
        next if tgt_role_unames.include? params[eak]

        category = ea_rct.content
        if !category  # should never happen
          raise "NOTE: A category is nil. For some reason, in testing, sometimes the RoleCategory.tree returns a single node (root only)  eak=#{eak.inspect}, params=#{params.inspect}, tgt_role_unames=#{tgt_role_unames.inspect} for ea_rct=#{ea_rct.inspect}, trees.size=#{si=RoleCategory.trees.size; (si==1) ? si.to_s : 'and tree='+RoleCategory.tree.inspect}"
        elsif !category.respond_to? :lowest_role  # should never happen
          raise "NOTE: A category(=ea_rct.content) is not RoleCategory. tree_each=#{ea_rct.inspect}"
        end
        if params[eak].downcase == 'none' 
          alert = cancel_role_in_category(category)
          raise ActiveRecord::Rollback, "Force rollback." if alert
          break
        end

        alert = assign_role_in_category(category, params[eak].downcase)
        raise ActiveRecord::Rollback, "Force rollback." if alert
        break
      end
    end

    respond_to do |format|
      if alert
        format.html {redirect_to user_path(@user), alert: alert }
      elsif @user.save
        logger.info "Roles are successfully updated to #{@user.roles.map{|i| (i.uname || i.name)}.inspect} for User ID=#{@user.id} (#{@user.display_name}) by User ID=#{current_user.id} (#{current_user.display_name})."
        format.html {redirect_to user_path(@user), notice: "Roles for User (#{@user.display_name}) were updated."}
          ## NOTE: Without format.html{}, it would result in ActionController::UnknownFormat
        #format.json { render :show, status: :ok, location: @user }
      else
        logger.error "FAIL in save (to update roles for User ID=#{@user.id} (#{@user.display_name}): Messages: "+@user.errors.full_messages.inspect
        format.html { redirect_to user_path(@user), alert: "Failed in updating roles for User ID=#{@user.id} (#{@user.display_name})." }
        format.json { render json: @user.errors, status: :unprocessable_content }
      end
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_user
      params.require(:id)
      @user = User.find(params[:id])
      user_params
    end

    # Only allow a list of trusted parameters through.
    def user_params
      #params.require(:user).permit(User::DEACTIVATE_METHOD_FORM_NAME)
    end

    # @param category [RoleCategory]
    # @return [String,NilClass] Error message (nil if normal return)
    def cancel_role_in_category(category, ignore_error: false)
      # current_person banned to manage a role for someone higher in rank than him/her or
      # if he has no roles in the RoleCategory
      tgt_highest = @user.highest_role_in(category)
      cur_highest = current_user.highest_role_in(category)
#logger.debug "DEBUG-can9: highest=#{cur_highest.inspect}"
      if !cur_highest || (tgt_highest && (tgt_highest < cur_highest))
        logger.error "Weirdly (no Web interface), Current User-ID=#{current_user.id} (Role=#{cur_highest ? (cur_highest.uname || cur_highest.name) : 'nil'}) attempted to cancel a role in RoleCategory[:#{category.mname}] for User-ID=#{@user.id} (Role=#{tgt_highest ? (tgt_highest.uname || tgt_highest.name) : 'nil'}) for which s/he is not qualified."
        logger.error "Rollback..."
        return "You are not qualified to update the role or update a role for a user who is higher in rank than you. [ErrorUpdateHigherRankRole]"
      end

      uroles = @user.roles
      category.roles.each do |ea_role| 
        # current_person cannot cancel a role higher in rank than his/hers.
        next if !current_user.qualified_as?(ea_role)
        next if (cur_highest == ea_role) && (@user != current_user)  # User cannot demote his colleague at the same highest-level role (in the RoleCategory) as he.
        next if !uroles.include?(ea_role)

        if ea_role.sysadmin? && Role[:admin].users.count == 1
          logger.error "Weirdly (no Web interface), Current User-ID=#{current_user.id} (Role=#{cur_highest ? (cur_highest.uname || cur_highest.name) : 'nil'}) attempted to cancel his/her sysadmin role a role, but prohibited because s/he is the sole sysadmin. [ErrorCancelSysadmin]"
          logger.error "Rollback..."
          return "You cannot cancel the sysadmin role as the sole sysadmin. [ErrorCancelSysadmin]"
        end
        uroles.destroy(ea_role)
      end
      nil
    end

    # @param category [RoleCategory]
    # @return [String,NilClass] Error message (nil if normal return)
    def assign_role_in_category(category, tgt_role_uname)
      alert = cancel_role_in_category(category)
      return alert if alert

      role2assign = Role[tgt_role_uname, category.mname]
      if !current_user.qualified_as?(role2assign)
        logger.error "Weirdly (no Web interface), User-ID=#{current_user.id} (Roles=#{current_user.roles.map{|i| i.id}.inspect}) attempted to promote User-ID=#{@user.id} to Role[:#{params[eak]}] for which s/he is not qualified.  [ErrorUpdateToHigherRankRole]"
        logger.error "Rollback..."
        return "You cannot promote a user to a higher rank than you. [ErrorUpdateToHigherRankRole]"
      end

      #UserRoleAssocs.create!(user: @user, role: role2assign)
      @user.roles << role2assign
      logger.info "Role (ID=#{role2assign.id}: #{(role2assign.uname || role2assign.name)}) of Category (#{category.mname}) is assigned to User ID=#{@user.id} (#{@user.display_name}) by User ID=#{current_user.id} (#{current_user.display_name})."
      nil
    end
end
