class UrlsController < ApplicationController
  include BaseWithTranslationControllerMethods  # for model_params, set_kind_from_params etc
  include ModuleCommon  # for contain_asian_char, txt_place_pref_ctry
  include ModuleGridController # for set_grid
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

  # Required in {BaseWithTranslationControllerMethods}: +[:disallow_nil, :allow_nil, :always_nil]+
  ORIG_LOCALE_TYPE_ON_CREATE = :allow_nil

  # GET /urls or /urls.json
  def index
    @urls = Url.left_joins(:domain).left_joins(:domain_title).order("domain_titles.weight", "domain_titles.created_at", "domains.weight", "domains.created_at", "urls.weight", "urls.created_at")
    set_grid(Url, hs_def: {order: :updated_at, descending: true})  # setting @grid; defined in concerns/module_grid_controller.rb
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
    super do |record|  # sets @record, @url and authorize; defined in base_with_translation_controller_methods.rb
      find_or_create_and_assign_domain(record)
    end
  end

  # PATCH/PUT /urls/1 or /urls/1.json
  def update
    @record = @url
    @record.attributes = model_params  # sets orig_locale *if* Controller gives one.
    def_respond_to_format(@url, :updated){
      if !@hsmain[:domain_id].nil? && @hsmain[:domain_id].blank?  # If nil, it is not from Web HTTP, but artificial testing, so we ignore it.  Note that since we use @hsmain, I am not sure if the key exists in the passed params or not.
        @url.domain_id = nil
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
  #   The caller should put the call in a DB transaction because this method may save records in DB.
  #
  # @param url2save [Url] If called from an instance method, pass @url
  # @return [Url] +errors.any?+ is true if an error happens and finding/creating has failed.
  def find_or_create_and_assign_domain(url2save)
    return url2save if !url2save.domain_id.blank?  # domain_id is already set.

    return url2save if !(ret=url2save.find_or_create_and_reset_domain_id)  # Returns only if an error has happened in creation of Domain/DomainTitle (as deemed necessary) for +url2save+, in which case +url2save.errors+ should have been set.
    return url2save if url2save.errors.any? || !url2save.domain  # This should be unnecesary and redundant, but playing safe.

    if (msgs=url2save.domain.notice_messages).present?
      # Transfers notice messages to flash.
      msgs.each do |em|
        add_flash_message(:notice, em)
      end
    else
      # should never happen, but playing safe...
      logger.error("ERROR: Uri#domain contains nil notice_messages, which should never happen after Domain has been either found or created successfully according in Domain.find_or_create_domain_by_url!")
      logger.error("ERROR: Here, Uri/Domain has pIDs=#{[url2save.id, url2save.domain.id]} / url=#{url2save.url.inspect})")
    end
    url2save
  end

  private
    ## Use callbacks to share common setup or constraints between actions.
    #def set_url
    #  @url = Url.find(params[:id])
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
