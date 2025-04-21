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
    @domains = Domain.all  # not sorted; the caller may use sorting/ordering like:  left_joins(domain_title: :translations).order("domain_titles.weight", "translations.title", "domains.weight", "domains.created_at").uniq  (distinct would fail)
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
    def_respond_to_format(@domain, :created){             # defined in application_controller.rb
      _assign_or_create_domain_title
      !@domain.errors.any? && @domain.save
    }
  end

  # PATCH/PUT /domains/1 or /domains/1.json
  def update
    def_respond_to_format(@domain, :updated){
      _assign_or_create_domain_title  # This sets the edited parameters to the record, too.
      !@domain.errors.any? && @domain.save
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

    # When {#domain_title_id} is blank, find the right parent {DomainTitle} or initialize one.
    #
    # +@domain+ is assumed to be set.
    #
    # @param dt_id [Integer, String, NilClass] the pID of {DomainTitle}
    # @return [Integer, DomainTitle, NilClass] Already-set pID of (unchecked) {DomainTitle} or found or new (unsaved) {DomainTitle}.  nil if fails.
    def _find_or_initialize_domain_title_assigned(dt_id=@hsmain.domain_title_id, domain=@hsmain.domain)
      return if dt_id.nil?      # nil means it was artificially set (for testing?) rather than via HTTP POST/PATCH interface. So, simply skipping the processing.
      return dt_id.to_i if dt_id.present?  # Integer

      domain = @domain.domain if domain.nil? && !@domain.new_record?   # nil means it was artificially set (for testing?) rather than via HTTP POST/PATCH interface in update. So, taking the value from the instance
      return if @domain.domain.blank?      # returns nil

      ret = @domain.find_or_initialize_domain_title_to_assign
      add_flash_message(:notice, "DomainTitle identified and assigned: "+ret.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: "")) if !ret.new_record?
      ret  # DomainTitle
    end


    # Assign DomainTitle, creating one if necessary.
    #
    # The caller should see @domain.errors.any? -  an error is set if creating a new DomainTitle fails,
    # In that case, the caller should not carry on processing.
    #
    # @note
    #    This method should be within a DB transaction.
    #
    # @param for_create [Boolean] true if :create or false (if :update)
    # @return [void]
    def _assign_or_create_domain_title(for_create=@domain.new_record?)
      @domain.assign_attributes(@hsmain) if !for_create  # for :update, no newly-edited parameters have been set, yet.

      ar = [:domain_title_id, :domain].map{ |ek|
        (@hsmain.has_key?(ek) ? @hsmain[ek] : @domain.send(ek))  # the latter happens only in artificial testing cases.
      }
      dt = _find_or_initialize_domain_title_assigned(*ar)

      if dt.respond_to?(:save)
        if dt.new_record?
          stat = dt.save
          if !stat
            @domain.errors.add :domain_title_id, "Failing in creating DomainTitle with an error message: "+dt.errors.full_messages.join("  ")
            return
          end
          add_flash_message(:notice, "DomainTitle created: "+dt.reload.title_or_alt(langcode: I18n.locale, lang_fallback_option: :either, str_fallback: ""))
        end
        @domain.domain_title_id = dt.id
      elsif dt.nil?
        # do nothing
      else  # Integer
        @domain.domain_title_id = dt
      end
    end
    private :_assign_or_create_domain_title

end
