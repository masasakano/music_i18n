class Users::ConfirmsController < ApplicationController
  # respond_to :html

  before_action :set_user, only: [:update]
  load_and_authorize_resource :user

  # GET /users/confirm.1
  def update
    if @user.confirmed?
      logger.warn "(#{self.class}) User (#{@user.display_name}; ID=#{@user.id}) has been already confirmed. No change."
      redirect_to users_path, notice: "User (#{@user.display_name}) has been already confirmed. No change."
      return
    end

    # Skip all notifications.
    @user.skip_confirmation_notification!
    @user.skip_confirmation!
    @user.skip_reconfirmation!
    @user.confirm
    # @see https://rubydoc.info/github/plataformatec/devise/Devise/Models/Confirmable

    if @user.save
      logger.info "(#{self.class}) User ID=#{@user.id} (#{@user.display_name}) was successfully confirmed (requested by User-ID=#{current_user.id})."
      if current_user && current_user.moderator?  # redundant because it is controlled in /app/models/ability.rb
        redirect_to users_path, notice: "User (#{@user.display_name}) was successfully confirmed."
        ## NOTE: Without format.html{}, it would result in ActionController::UnknownFormat ??
      else
        redirect_to root_path, notice: "User account was successfully confirmed."
      end
    else
      logger.error "(#{self.class}) FAIL in confirm-ing a user (#{@user.display_name}; ID=#{@user.id})): Messages: "+@user.errors.full_messages.inspect
      redirect_to root_path, notice: "Failed in confirming (#{@user.display_name}) for an unknown reason."
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id] || params[:format])
      # user_params  # (maybe defined below)
    end
end
