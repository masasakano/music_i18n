# coding: utf-8

# Controller to populate data from a {Harami1129} row to the DB
class Harami1129s::PopulatesController < ApplicationController
  before_action :authorize_for_edit, only: [:update]

  # PATCH/PUT /harami1129s/1/populates
  # PATCH/PUT /harami1129s/1/populates.json (???)
  def update
    Translation.skip_set_user_callback = true  # in order NOT to set create_user_id in Translation

    i = params[:id] || params[:harami1129_id]
    @harami1129 = Harami1129.find(i)
    msg = []
    kwds = {messages: msg}

    if params.has_key?("harami1129")
      prms = params.require(:harami1129).permit(:recreate_harami_vid)
      kwds[:recreate_harami_vid] = convert_param_bool(prms[:recreate_harami_vid], true_int: 1)
      ## or...
      # 
      # if (prm = params.permit(harami1129: {})[:harami1129])
      #   prm = prm.permit(:recreate_harami_vid)[:recreate_harami_vid] 
    end

    respond_to do |format|
      if @harami1129.populate_ins_cols_default(**kwds)  # msg may be updated (it is intent(out)!).
        msg << "Successfully populated." if msg.respond_to?(:map)
        format.html { redirect_to @harami1129, notice: msg }
        format.json { render :show, status: :ok, location: @harami1129 }
      else
        @harami1129.errors.add :base, flash[:alert] if flash[:alert].present? # alert is, if present, included in the instance
        hsflash = {}
        %i(warning notice).each do |ek|
          hsflash[ek] = flash[ek] if flash[ek].present?
        end
        opts = get_html_safe_flash_hash(alert: @harami1129.errors.full_messages, **hsflash)
        hsstatus = {status: :unprocessable_entity}
        # Since this is "recirect_to", everything must be passed as flash (not in the form of @record.errors)
        format.html { redirect_to @harami1129, **(opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: @harami1129.errors, **hsstatus }
      end
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
