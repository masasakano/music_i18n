class DomainTitlesController < ApplicationController
  include ModuleCommon  # for contain_asian_char, txt_place_pref_ctry
  include ModuleMemoEditor   # for memo_editor attribute

  # before_action :set_domain_title, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @domain_title
  before_action :model_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  # NOTE: In addition, "event_item_ids" is used, but it is a key for an Array, hence defined separately in model_params_multi() (as an exception)
  MAIN_FORM_KEYS ||= []
  MAIN_FORM_KEYS.concat(
    %i(site_category_id weight note) + [])

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_type_params_multi()

  # GET /domain_titles or /domain_titles.json
  def index
    @domain_titles = DomainTitle.order(:weight)
  end

  # GET /domain_titles/1 or /domain_titles/1.json
  def show
  end

  # GET /domain_titles/new
  def new
    @domain_title = DomainTitle.new
  end

  # GET /domain_titles/1/edit
  def edit
  end

  # POST /domain_titles or /domain_titles.json
  def create
    @domain_title = DomainTitle.new(@hsmain)
    authorize! __method__, @domain_title

    add_unsaved_trans_to_model(@domain_title, @hstra, force_is_orig_true: false) # defined in application_controller.rb
    def_respond_to_format(@domain_title)              # defined in application_controller.rb
  end

  # PATCH/PUT /domain_titles/1 or /domain_titles/1.json
  def update
    def_respond_to_format(@domain_title, :updated){
      @domain_title.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /domain_titles/1 or /domain_titles/1.json
  def destroy
    @domain_title.destroy

    respond_to do |format|
      format.html { redirect_to domain_titles_url, notice: "DomainTitle was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    ## Use callbacks to share common setup or constraints between actions.
    #def set_domain_title
    #  @domain_title = DomainTitle.find(params[:id])
    #end

    ## Only allow a list of trusted parameters through.
    #def domain_title_params
    #  params.require(:domain_title).permit(:site_category_id, :weight, :note, :memo_editor)
    #end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main_tra(:domain_title) # defined in application_controller.rb
    end
end
