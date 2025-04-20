class UrlsController < ApplicationController
  include ModuleCommon  # for contain_asian_char, txt_place_pref_ctry
  include ModuleMemoEditor   # for memo_editor attribute

  # before_action :set_url, only: %i[ show edit update destroy ]
  load_and_authorize_resource except: [:create] # This sets @url
  before_action :model_params_multi, only: [:create, :update]

  # Symbol of the main parameters in the Form (except "place" (or "place_id"?)), which exist in DB or as setter methods
  # NOTE: In addition, "event_item_ids" is used, but it is a key for an Array, hence defined separately in model_params_multi() (as an exception)
  MAIN_FORM_KEYS ||= []
  MAIN_FORM_KEYS.concat(
    %i(url url_langcode domain_id weight note) + [
      "published_date(1i)", "published_date(2i)", "published_date(3i)",
      "last_confirmed_date(1i)", "last_confirmed_date(2i)", "last_confirmed_date(3i)",
    ])
    # NOTE: NOT "url_normalized" becauset it should not be user-editable, including an admin.
    # NOTE: create_user_id update_user_id are not included.

  # Permitted main parameters for params(), used for update and create
  PARAMS_MAIN_KEYS = MAIN_FORM_KEYS
  # these will be handled in channel_type_params_multi()

  # GET /urls or /urls.json
  def index
    @urls = Url.left_joins(:domain).left_joins(:domain_title).order("domain_titles.weight", "domain_titles.created_at", "domains.weight", "domains.created_at", "urls.weight", "urls.created_at")
  end

  # GET /urls/1 or /urls/1.json
  def show
  end

  # GET /urls/new
  def new
    @url = Url.new
  end

  # GET /urls/1/edit
  def edit
  end

  # POST /urls or /urls.json
  def create
    @url = Url.new(@hsmain)
    authorize! __method__, @url

    add_unsaved_trans_to_model(@url, @hstra, force_is_orig_true: false) # defined in application_controller.rb
    def_respond_to_format(@url, :created){              # defined in application_controller.rb
      find_or_create_and_assign_domain(@url)
      @url.errors.any? ? false : @url.save
    }
  end

  # PATCH/PUT /urls/1 or /urls/1.json
  def update
    def_respond_to_format(@url, :updated){
      if !@hsmain[:domain_id].nil? && @hsmain[:domain_id].blank?  # If nil, it is not from Web HTTP, but artificial testing, so we ignore it.  Note that since we use @hsmain, I am not sure if the key exists in the passed params or not.
        @url.domain_id = ""
        @url.url = @hsmain[:url]  # These two assignments are essential to auto-update domain_id
        find_or_create_and_assign_domain(@url)
      end
      hs = @hsmain.merge(domain_id: @url.domain_id).with_indifferent_access
      @url.errors.any? ? false : @url.update(hs)
    } # defined in application_controller.rb
  end

  # DELETE /urls/1 or /urls/1.json
  def destroy
    @url.destroy

    respond_to do |format|
      format.html { redirect_to urls_url, notice: "Url was successfully destroyed." }
      format.json { head :no_content }
    end
  end


  # If @url.domain_id is blank, assign one, potentially creating Domain (and maybe DomainTitle)
  #
  # @note
  #   The caller should put the call in a DB transaction.
  #
  # @param url2save [Url] If called from an instance method, pass @url
  # @return [Url]
  def find_or_create_and_assign_domain(url2save)
    return url2save if !url2save.domain_id.blank?
    begin
      url2save.domain = Domain.find_or_create_domain_by_url!(url2save.url) 
    rescue => err
      url2save.errors.add :domain_id, err.message
    end

    return url2save if url2save.errors.any? || !url2save.domain

    url2save.domain.notice_messages.each do |em|
      add_flash_message(:notice, em)
    end
    url2save
  end

  private
    ## Use callbacks to share common setup or constraints between actions.
    #def set_url
    #  @url = Url.find(params[:id])
    #end

    ## Only allow a list of trusted parameters through.
    #def url_params
    #  params.require(:url).permit(:url, :url_normalized, :url_langcode, :domain_title_id, :weight, :published_date, :last_confirmed_date, :create_user_id, :update_user_id, :note, :memo_editor)
    #end

    # Sets @hsmain and @hstra and @prms_all from params
    #
    # +action_name+ (+create+ ?) is checked inside!
    #
    # @return NONE
    def model_params_multi
      hsall = set_hsparams_main_tra(:url) # defined in application_controller.rb
    end

end
