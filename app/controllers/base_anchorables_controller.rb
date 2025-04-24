class BaseAnchorablesController < ApplicationController

  include ModuleCommon  # for guess_lang_code
  include BaseAnchorablesHelper  # for path_anchoring

  skip_before_action :authenticate_user!, only: [:index, :show]
  # load_and_authorize_resource except: [:index, :show, :create]
  before_action :set_anchoring, except: [:index, :new, :create]
  before_action :set_new_anchoring, only:       [:new, :create]
  before_action :auth_for!    , except: [:index, :new, :create, :show]

  def index
    key = params_id
    @anchorings = Anchoring.where(key => params[key])  # no ordering/sorting here.
  end

  def new
    @url = Url.new
    authorize! __method__, @anchorable.class
    #render turbo_stream: turbo_stream.replace("new_anchoring_form", partial: 'form', locals: { record: @anchorable, anchoring: @anchoring })
  end

  def show
  end

  def edit
    if @anchoring.url
      @anchoring.url_form = @anchoring.url.url
      @anchoring.site_category_id = ((sc=@anchoring.site_category) ? sc.id : nil)

      (Anchoring::FORM_ACCESSORS - %i(site_category_id title langcode is_orig url_form note)).each do |metho|
        @anchoring.send(metho.to_s+"=", @anchoring.url.send(metho))
      end
    end
  end

  def create
    authorize! __method__, @anchorable.class
    @anchoring.assign_attributes(anchoring_params)
    _adjust_for_wikipedia(@anchoring)
    _adjust_for_harami_chronicle(@anchoring)

    opts = %i(site_category_id url_langcode weight title).map{|metho| [metho, @anchoring.send(metho)]}.to_h  # langcode is guessed from title in Url.def_translation_from_url()
    opts[:langcode] = @anchoring.langcode if @anchoring.langcode.present?  # not via Website UI but by some methods
    opts[:is_orig]  = @anchoring.is_orig  if [true, false].include? @anchoring.is_orig

    status, msgs = _create_update_core(@anchoring){ |anchoring|
      anchoring.url = Url.find_or_create_url_from_str(anchoring.url_form, **opts)
    }
    respond_to do |format|
      if status
        format.html { redirect_to path_anchoring(@anchoring, action: :show), notice: msgs }
        format.turbo_stream
      else
        path = path_anchoring(@anchoring, action: :new) # defined in Artists::AnchoringsHelper
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @anchoring.assign_attributes(anchoring_params)
    _transfer_prms_from_anchoring_to_url(@anchoring)
    _adjust_for_wikipedia(@anchoring)
    _adjust_for_harami_chronicle(@anchoring)

    status, msgs = _create_update_core(@anchoring){ |anchoring|
      anchoring.url.reset_assoc_domain(force: true, site_category_id: @anchoring.site_category_id) if anchoring.url
    }

    respond_to do |format|
      if status
        format.html { redirect_to path_anchoring(@anchoring, action: :show), notice: msgs }
      else
        #path = url_anchoring(@anchoring, action: :edit) # defined in Artists::AnchoringsHelper
        ## path = Rails.application.routes.url_helpers.polymorphic_path(@anchoring.anchorable, action: :edit)
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    path_back = Rails.application.routes.url_helpers.polymorphic_path(@anchoring.anchorable.class)
    respond_to do |format|
      if @anchoring.destroy
        format.html { redirect_to path_back, notice: "Link was successfully destroyed." }
        format.turbo_stream
        format.json { head :no_content }
      else
        format.html { redirect_to path_back, status: :unprocessable_entity }
        format.json { render json: @anchoring.errors, status: :unprocessable_entity }
      end
    end
  end

  private  ########################################################################

    # key name to be used for Anchoring path helpers, e.g., "artist_id"
    #
    # @return [Symbol]
    def params_id
      (self.class::ANCHORABLE_CLASS.name.underscore + "_id").to_sym
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_anchoring
      @anchorable = self.class::ANCHORABLE_CLASS.find params[params_id]
      @anchoring = Anchoring.find(params[:id])
    end

    def set_new_anchoring
      key = params_id
      @anchorable = self.class::ANCHORABLE_CLASS.find params[key]
      @anchoring = Anchoring.new(anchorable_type: self.class::ANCHORABLE_CLASS.name, anchorable_id: params[key])
    end

    # Common authorization (Note that the action must be Symbol!!)
    def auth_for!(method=action_name)
      authorize! method.to_sym, @anchorable  # Authorize according to the same-name method for anchorable (like Artist)
    end

    # 
    def anchoring_params
      params.require(:anchoring).permit(:site_category_id, :title, :langcode, :url_form, *UrlsController::MAIN_FORM_KEYS)  # this is more permissive than the actual form parameters; langcode and many in MAIN_FORM_KEYS are not provided to UI (see _transfer_prms_from_anchoring_to_url for detail)
    end

    # transfer parameters from Anchoring to (existing) Url
    #
    # So far, url_form, url_langcode, weight are the only parameters in Form (apart from :title)
    #
    # c.f. Anchoring::FORM_ACCESSORS
    def _transfer_prms_from_anchoring_to_url(anchoring, url=anchoring.url)
      url.url = Url.normalized_url(anchoring.url_form)
      url.url_langcode = anchoring.url_langcode
      url.weight       = anchoring.weight if anchoring.weight.present?
    end

    # transfer errors from Url to Anchoring
    #
    def _transfer_error_from_url(anchoring, url=anchoring.url)
      anchoring.url.errors.each do |err|
        error_type = 
          case err.attribute
          when :url
            :url_form
          when :url_langcode, :weight
            err.attribute
          else
            :base
          end
        anchoring.errors.add error_type, err.message
      end
    end


    # Core routine of create/update
    #
    # The caller should set/update anchoring.url here, which is performed within a DB transaction.
    # +anchoring.errors+ is set in failing (which includes the error messages in creating Url, Domain, DomainTitle).
    #
    # @param anchoring [Anchoring]
    # @return [Array] 2-element Array of [Boolean, Array<String>] of the save-status (true if successful) and messages.
    # @yield [Anchoring] The caller should set/update anchoring.url here, which is within a DB transaction.  Its return value can be anything (not used here).
    def _create_update_core(anchoring=@anchoring)
      status, msgs = [nil, nil]

      ActiveRecord::Base.transaction(requires_new: true) do
        yield(anchoring)
        msgs = anchoring.url.domain.notice_messages if anchoring.url && anchoring.url.domain  # Domain was created/found etc when the domain part of Url#url changed.

        status = !anchoring.url.errors.any?  # Domain/DomainTitle creation fails.  url.errors is set.
        status &&= anchoring.url.save  # Url update fails (e.g., an invalid URL is specified).
        _transfer_error_from_url(anchoring) if !status
        status &&= anchoring.save      # Anchoring update fails (unexpectedly).

        raise ActiveRecord::Rollback, "Force rollback." if !status
      end

      if status
        msgs ||= []
        msgs.push "Url was successfully updated: "+anchoring.url.url
        # NOTE: whether created or not is a bit tricky to find, hence "updated".
      end

      [status, msgs]
    end
    private :_create_update_core

    # Auto-adjusts some parameters for Wikipedia
    def _adjust_for_wikipedia(anchoring=@anchoring)
      url_w_scheme = ModuleUrlUtil.url_prepended_with_scheme(anchoring.url_form)
      return if url_w_scheme.blank?
      urin = URI.parse(url_w_scheme)
      return if /^([a-z]{2})\.wikipedia\.org$/ !~ urin.host.downcase  # Not Wikipedia

      site_lang = $1
      anchoring.url_langcode = site_lang if anchoring.url_langcode.blank?
      return if !anchoring.new_record? || !anchoring.title.blank?

      anchoring.title = URI.decode_www_form_component(urin.path.sub(%r@^/?wiki/@, ""))
      anchoring.langcode = site_lang
      anchoring.is_orig = true
    end
    private :_adjust_for_wikipedia

    # Auto-adjusts some parameters for Wikipedia
    #
    def _adjust_for_harami_chronicle(anchoring=@anchoring)
      url_w_scheme = ModuleUrlUtil.url_prepended_with_scheme(anchoring.url_form)
      return if url_w_scheme.blank?
      urin = URI.parse(url_w_scheme)

      dom = Domain.find_by_both_urls(url_w_scheme)
      return if !dom

      sc = dom.site_category
      return if "chronicle" != sc.mname
      return if dom.domain_title != sc.domain_titles.order(:created_at).first  # Chronicle but not the default (=first seeded) one.

      ## Only for new_record? so far
      return if !@anchoring.new_record?
      anchoring.url_langcode = "ja" if anchoring.url_langcode.blank?
      #@anchoring.title = 
    end
    private :_adjust_for_harami_chronicle

end
