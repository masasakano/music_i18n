# coding: utf-8

# Controller to populate data from a {Harami1129} row to the DB
class Harami1129s::PopulatesController < ApplicationController
  before_action :authorize_for_edit, only: [:update]

  # PATCH/PUT /harami1129s/1/populates
  # PATCH/PUT /harami1129s/1/populates.json (???)
  def update
    Translation.skip_set_user_callback = true  # in order NOT to set create_user_id in Translation

    respond_to do |format|
      i = params[:id] || params[:harami1129_id]
      @harami1129 = Harami1129.find(i)
      msg = []
      @harami1129.populate_ins_cols_default(messages: msg)  # msg may be updated (it is intent(out)!).
      format.html { redirect_to @harami1129, notice: (msg.empty? ? "Successfully populated." : msg)}
      format.json { render :show, status: :ok, location: @harami1129 }
    end
  end

  protected

  private
    def populates_params
      params.permit(:id, :harami1129_id)
      # params.require(:harami1129).permit(:id, :harami1129_id)
    end

    def authorize_for_edit
      if !current_user
        head :unauthorized
        raise ActionController::RoutingError.new('Not authenticated...')
      elsif !current_user.moderator?
        logger.info sprintf('(%s#%s) User (ID=%d) access forbidden', self.class.name, __method__, current_user.id)
        render(:file => File.join(Rails.root, 'public/403.html'), :status => :forbidden, :layout => false)
        #render status: :forbidden
        raise ActionController::RoutingError.new('Not authorized...')
      end
    end
end
