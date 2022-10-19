# -*- coding: utf-8 -*-

# = Strategy
#
# In short, {#destroy} method is valid only to deactivate self, and it is forwarded to rename_user().
# For the priviledged users, {#update} is used to deactivate (maybe destroy) another user.
#
# == user is sysadmin
#
# * edit : screen to input parameters to deactivate a user: [GET] /users/123/deactivate_users/edit
# * update : [PATCH] /users/123/deactivate_users
#   * require params[:user][:deactivate_method]
#   * case    params[:user][:deactivate_method]
#     * when 'destory': run destroy_completely()
#       * User has children in :user_role_assocs with "dependent: :destroy" and "Translation" with "dependent: :nullify"; n.b., it is handled in Rails level and without it the DB would raise an Exception.
#     * else (=='rename'): run rename_user()
# * destroy : [DELETE] /users/123/deactivate_users
#   * the same as that for a normal user; However, sysadmin themselves is banned to call this.
#
# == user is moderator
#
# * edit : only if the user is less privileged; otherwise, not authorized.
#   * At the view level, no option for destroy is provided.
#   * less privileged:
#     1. if s/he and/or the user to disable the account is an admin, that is the role to evaluate the privilege.
#     2. if not, s/he is qualified only if s/he is higher in rank in all the {RoleCategory} the user to disable the account belongs to. For example, if s/he has no role in {RoleCategory} Kei, for which the user to disable the account is a {Role} receptionist, s/he is NOT qualified.
# * update : only if the user is less privileged; otherwise, not authorized (in ability.rb).
#     * when 'destory': banned (no option is provided in view)
#     * else (=='rename'): run rename_user() only if the user is less privileged; otherwise, not authorized (at the method level).
# * destroy : [DELETE] /users/123/deactivate_users
#   * the same as that for a normal user.
#
# == user is less priviledged
#
# * edit : not authorized.
# * update : not authorized.
# * destroy : [DELETE] /users/123/deactivate_users
#   * only if the user is self; otherwise, not authorized.
#   * run rename_user()
#
class Users::DeactivateUsersController < ApplicationController
  before_action :set_user, only: [:update, :edit, :destroy]
  #load_and_authorize_resource :user
  load_and_authorize_resource

  # GET /users/1/deactivate_users/edit
  def edit
    if (current_user == @user)
      logger.error "User ID=#{@user.id} somehow manages to fetch the edit page to destroy his/her own account, which should not happen (#{__FILE__}\##{__method__})."
      render file: Rails.root.join("public/500.html"), layout: false, status: '500'  # Internal Server Error
      return
    end
  end

  # Update the USER display_name etc to "exuser-123" and anonymize her/him.
  #
  # PATCH/PUT /users/1/deactivate_users
  # PATCH/PUT /users/1.json/deactivate_users
  def update
    return prevent_sysadmin_cancel if @user.sysadmin?  # This should never happen.

    case params['user'][User::DEACTIVATE_METHOD_FORM_NAME]  # ERB: form_with(model: @user) => 'user'
    when 'destroy'
      if !(current_user && current_user.sysadmin?)
        logger.error "User ID=#{@user.id} somehow manages to attempt to destroy their account, which should not happen (#{__FILE__}\##{__method__})."
        render file: Rails.root.join("public/500.html"), layout: false, status: '500'  # Internal Server Error
        return
      end

      destroy_completely
      return
    when 'rename'
      # Do nothing
    else
      raise "method is unexpected: #{params[DEACTIVATE_METHOD_FORM_NAME.to_sym].to_s.inspect}"
    end

    rename_user
  end

  # Action for DELETE called by a user to deactivate themselves
  #
  def destroy
    return prevent_sysadmin_cancel if @user.sysadmin?  # This should never happen.
    rename_user
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
#print 'DEBUG0:action_name=';p action_name
#print 'DEBUG1:params=';p params
      params.require(:id)
      @user = User.find(params[:id])
      user_params if :update == action_name.to_sym
    end

    # Only allow a list of trusted parameters through.
    def user_params
#print 'DEBUG2:params=';p params
      #params.require(:user).permit(User::DEACTIVATE_METHOD_FORM_NAME)
      params.require(:user).permit(User::DEACTIVATE_METHOD_FORM_NAME).tap do |tmp_params|
        tmp_params.permit(User::DEACTIVATE_METHOD_FORM_NAME)
      end
    end

    # prevent sysadmin from canceling/deactivating/deleting their account
    def prevent_sysadmin_cancel
      logger.error "User ID=#{@user.id} display_name=(#{@user.display_name}) is attempted to be destroyed by User-ID=#{current_user.id} but forbidden because s/he is "+(@user.sysadmin? ? 'a sysadmin.' : 'an admin')
      flash.now[:error] = "admin account cannot be cancelled."
      render file: Rails.root.join("public/500.html"), layout: false, status: '500'  # Internal Server Error
    end

    # Deactivate the user by renaming
    #
    def rename_user
      newpass = [*(?a..?z),*(?A..?Z),*('0'..'9')].shuffle[0,20].join  # 20 random alphanumeric characters (> Ruby 1.9)

      orgname = @user.display_name
      if (orgname == @user.get_exuser_name)
        # It has been already renamed. Hence nothing is done.
        logger.info "(#{__method__}) User account (ID=#{@user.id}) has been already deactivated. No change is made."
        redirect_to users_path, notice: "User account has been already deactivated. No change is made."
        #format.html { redirect_to root_path, notice: "User account has been already deactivated. No change is made." }
        ## NOTE: format.html{} would result in sticking to the "update" page, which does not exist, hence no transition of the page.
        return
      end

      @user.display_name = @user.get_exuser_name
      @user.email        = @user.get_exuser_email
      @user.password              = newpass
      @user.password_confirmation = newpass
      @user.last_sign_in_at        = Time.now.utc
      @user.current_sign_in_ip   = nil
      @user.last_sign_in_ip      = nil
      @user.confirmation_token   = nil
      @user.confirmed_at         = Time.now.utc
      @user.confirmation_sent_at = nil
      # @user.unconfirmed_email    = nil
      @user.ext_account_name     = nil
      @user.ext_uid              = nil
      @user.provider             = nil

      @user.skip_confirmation_notification!
      @user.skip_confirmation!
      @user.skip_reconfirmation!
      @user.confirm
      # @see https://rubydoc.info/github/plataformatec/devise/Devise/Models/Confirmable

      respond_to do |format|
        if @user.save
          logger.info "User ID=#{@user.id} (#{orgname}) was successfully deactivated (Now, Display_name=#{@user.display_name})."
          if current_user && current_user.sysadmin?
            format.html {redirect_to users_path, success: "User (#{orgname}) was successfully deactivated (Now, Display_name=#{@user.display_name})."}
            ## NOTE: Without format.html{}, it would result in ActionController::UnknownFormat
          else
            redirect_to root_path, success: "User account was successfully cancelled."
          end
          #format.json { render :show, status: :ok, location: @user }

        else
          logger.error "FAIL in save (to deactivate a user (#{orgname}; ID=#{@user.id})): Messages: "+@user.errors.full_messages.inspect
          format.html { render :edit, alert: "Failed in processing (#{orgname}) for an unknown reason." }
          format.json { render json: @user.errors, status: :unprocessable_entity }
        end
      end
    end

    # Destroys the user completely, ie., removes from DB
    def destroy_completely
      orgname = @user.display_name

      logger.info "User ID=#{@user.id} display_name=(#{orgname}) is destroyed."
      # @user.anonymize_all_my_trans! if @user.has_undestroyable_children?  # Redundant
      @user.destroy
      respond_to do |format|
        format.html { redirect_to users_path, success: "User (#{orgname}) was successfully removed from the DB." }
        #format.json { head :no_content }
      end
    end
end

