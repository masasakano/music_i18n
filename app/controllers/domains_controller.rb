class DomainsController < ApplicationController
  include ModuleCommon  # for contain_asian_char, txt_place_pref_ctry

  # before_action :set_domain, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @domain_title
  before_action :model_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  # NOTE: In addition, "event_item_ids" is used, but it is a key for an Array, hence defined separately in model_params_multi() (as an exception)
  MAIN_FORM_KEYS ||= []
  MAIN_FORM_KEYS.concat(
    %i(domain weight note domain_title_id domain_title) + [])

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_type_params_multi()


  # GET /domains or /domains.json
  def index
    @domains = Domain.left_joins(:domain_title).order("domain_titles.weight", "domains.weight", "domains.created_at")
  end

  # GET /domains/1 or /domains/1.json
  def show
  end

  # GET /domains/new
  def new
    @domain = Domain.new
  end

  # GET /domains/1/edit
  def edit
  end

  # POST /domains or /domains.json
  def create
    @domain = Domain.new(@hsmain)
    authorize! __method__, @domain
    def_respond_to_format(@domain)              # defined in application_controller.rb
  end

  # PATCH/PUT /domains/1 or /domains/1.json
  def update
    def_respond_to_format(@domain, :updated){
      @domain.update(@hsmain)
    } # defined in application_controller.rb
  end

  # DELETE /domains/1 or /domains/1.json
  def destroy
    @domain.destroy

    respond_to do |format|
      format.html { redirect_to domains_url, notice: "Domain was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    ## Use callbacks to share common setup or constraints between actions.
    #def set_domain
    #  @domain = Domain.find(params[:id])
    #end

    ## Only allow a list of trusted parameters through.
    #def domain_params
    #  params.require(:domain).permit(:domain, :domain_title_id, :note)
    #end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main(:domain) # defined in application_controller.rb
    end

end
