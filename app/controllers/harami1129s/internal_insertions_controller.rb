# coding: utf-8

module Harami1129s

# Controller to copy data from the columns to ins_* columns in the same row.
class Harami1129s::InternalInsertionsController < ApplicationController
  #load_and_authorize_resource  # raises: NameError (uninitialized constant InternalInsertion)
  before_action :authorize_for_edit, only: [:update, :update_all]

  # PATCH/PUT /harami1129s/1/internal_insertions
  # PATCH/PUT /harami1129s/1/internal_insertions.json (???)
  def update
    respond_to do |format|
      i = params[:id] || params[:harami1129_id]
      @harami1129 = Harami1129.find(i)
      msg = fill_ins_column!(id_in: i)
      format.html { redirect_to @harami1129, notice: msg }
      format.json { render :show, status: :ok, location: @harami1129 }
    end
  end

  # PATCH/PUT /harami1129s/internal_insertions
  # PATCH/PUT /harami1129s/internal_insertions.json (???)
  def update_all
    respond_to do |format|
      msg = fill_ins_column!
      format.html { redirect_to harami1129s_path, notice: msg }
      format.json { render :show, status: :ok, location: harami1129s_path }
    end
  end

  protected

  def fill_ins_column!(id_in: nil, force: false)
    n_updated = 0
    rela = (id_in ? Harami1129.where(id: id_in) : Harami1129.all)
    rela.each do |harami1129|
      harami1129.fill_ins_column!(force: force)
      n_updated += 1 if harami1129.ins_at_previously_changed?
    end

    # Construct a notification message.
    msg =
      if id_in
        msg_middle = ((n_updated > 0) ? "is updated" : "unchanges after an attempted update")
        sprintf "ID=%d in Harami1129 %s for ins_COLUMNS.", id_in, msg_middle
      else
        sprintf "%d/%d rows in Harami1129 are updated for ins_COLUMNS.", n_updated, Harami1129.count
      end
    logger.info sprintf('(%s#%s)', self.class.name, __method__)+msg
    msg
  end

  private
    def internal_insertions_params
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
end
