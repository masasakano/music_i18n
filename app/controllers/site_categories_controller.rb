class SiteCategoriesController < ApplicationController
  include ModuleCommon  # for contain_asian_char, txt_place_pref_ctry
  include ModuleMemoEditor   # for memo_editor attribute

  #before_action :set_site_category, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @site_category
  before_action :site_category_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  # NOTE: In addition, "event_item_ids" is used, but it is a key for an Array, hence defined separately in model_params_multi() (as an exception)
  MAIN_FORM_KEYS ||= []
  MAIN_FORM_KEYS.concat(
    %i(mname weight summary note) + [])

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_type_params_multi()

# GET /site_categories or /site_categories.json
  def index
    @site_categories = SiteCategory.order(:weight)
  end

  # GET /site_categories/1 or /site_categories/1.json
  def show
  end

  # GET /site_categories/new
  def new
    @site_category = SiteCategory.new
    @site_category.weight = SiteCategory.order(weight: :desc).limit(2).pluck(:weight).sum/2.0
  end

  # GET /site_categories/1/edit
  def edit
  end

  # POST /site_categories or /site_categories.json
  def create
    @site_category = SiteCategory.new(@hsmain)
    authorize! __method__, @site_category

    add_unsaved_trans_to_model(@site_category, @hstra, force_is_orig_true: false) # defined in application_controller.rb
    def_respond_to_format(@site_category)              # defined in application_controller.rb
  end

  # PATCH/PUT /site_categories/1 or /site_categories/1.json
  def update
    def_respond_to_format(@site_category, :updated){
      @site_category.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /site_categories/1 or /site_categories/1.json
  def destroy
    @site_category.destroy

    respond_to do |format|
      format.html { redirect_to site_categories_url, notice: "Site category was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    ## Use callbacks to share common setup or constraints between actions.
    #def set_site_category
    #  @site_category = SiteCategory.find(params[:id])
    #end

    ## Only allow a list of trusted parameters through.
    #def site_category_params
    #  params.require(:site_category).permit(:mname, :weight, :summary, :note, :memo_editor, :null, :false)
    #end


    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def site_category_params_multi
      hsall = set_hsparams_main_tra(:site_category) # defined in application_controller.rb
    end

end
