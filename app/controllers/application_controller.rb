# coding: utf-8
class ApplicationController < ActionController::Base
  include ApplicationHelper
  include ModuleCommon   # for split_hash_with_keys() etc
  extend ModuleCommon    # for convert_str_to_number_nil
  using ModuleHashExtra  # for extra methods, e.g., Hash#values_blank_to_nil

  protect_from_forgery with: :exception

  ## Uncomment this (as well as the method at the bottom) to investigate problems related to params() and/or authenticate/Controller
  #before_action :debug_ctrl_print1
  before_action :authenticate_user!
  # For public contents, use:  skip_before_action :authenticate_user!, :only => [:index, :show]  # Revert application_controller.rb so Index is viewable by anyone.

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_paper_trail_whodunnit
  before_action :set_translation_whodunnit
  before_action :set_current_user_for_grid #, except: [:destroy]  # This "except" clause would raise AbstractController::ActionNotFound exception in Rails-7.1 or later in the Controllers that do not define :destroy method, unless config.action_controller.raise_on_missing_callback_actions is set false. The "except" method is handled inside :set_current_user_for_grid
  ## Uncomment this (as well as the method below) to investigate problems related to params()
  #before_action :debug_ctrl_print2

  around_action :switch_locale

  # When a nil is passed as a value in a *collection* to simple_form selections,
  # which is often the case for a ternary selection,
  # there is a bug in simpl_form, which the W3C validator reports as
  #   > The value of the "for" attribute of the "label" element must be the ID of a non-hidden form control.
  # (Issue #1840 at https://github.com/heartcombo/simple_form/issues/1840)
  #
  # As a workaround, let us define a special value corresponding to nil for the form;
  # basically, this value is passed to the form instead of nil.
  # See, for an actual example, /app/views/layouts/_partial_new_translations.html.erb
  #
  # See also {ApplicationController.returned_str_from_form}.
  #
  # @example to get the string value for this
  #    ApplicationController.returned_str_from_form(ApplicationController::FORM_TERNARY_UNDEFINED_VALUE)
  #      # => "999999"
  #
  FORM_TERNARY_UNDEFINED_VALUE = 999999

  # (FORM) HTML IDs and CLASSes
  HTML_KEYS = {
    ids: {
      div_sel_country:    "div_select_country",
      div_sel_prefecture: "div_select_prefecture",
      div_sel_place:      "div_select_place",
    }.with_indifferent_access,
    classes: {
    }.with_indifferent_access,
  }.with_indifferent_access

  # In addition to the defaul "notice" and "alert".
  #
  # I assume "notice" => "alert-info", "alert" => "alert-danger" in Bootstrap.
  # @see https://api.rubyonrails.org/classes/ActionController/Flash/ClassMethods.html#method-i-add_flash_types
  # @see https://getbootstrap.com/docs/4.0/components/alerts/
  add_flash_types :success, :warning  # Rails 4+

  # HTML/CSS Class for flash messages
  FLASH_CSS_CLASSES = {
    alert:          "alert alert-danger",
    warning:        "alert alert-warning",
    success:        "alert alert-success",
    notice:  "notice alert alert-info",
  }.with_indifferent_access

  tmp_params_trans_keys = [:langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji]

  PARAMS_NAMES = {
    trans: tmp_params_trans_keys.map{|i| [i, i]}.to_h.with_indifferent_access
  }.with_indifferent_access
  PARAMS_NAMES[:trans][:is_orig] = :best_translation_is_orig

  # Common params keys for {Translation}.
  # @note +:is_orig+ is not included!
  PARAMS_TRANS_KEYS = PARAMS_NAMES[:trans].values # [:langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji, :best_translation_is_orig]  # NOT including :is_orig

  # Common params keys for {Place}.
  PARAMS_PLACE_KEYS = %i(place.prefecture_id.country_id place.prefecture_id place place_id)  # :place is used (place_id seems redundant(?) but the most basic UI may require it and so we leave it)

  # Unit used in Event/EventItem Forms
  EVENT_FORM_ERR_UNITS = [["days", "day"], ["hours", "hour"], ["minutes", "minute"]]

  # Default unit used in Event/EventItem Forms for Time-related errors.  This can be overwritten by DEF_FORM_TIME_ERR_UNIT in each Controller class!
  DEF_FORM_TIME_ERR_UNIT = "day"

  def default_url_options(options={})
    #Rails.application.default_url_options = Rails.application.routes.default_url_options = { locale: I18n.locale }
    { locale: I18n.locale }.merge options
  end

  # Exception handling when accessing an unauthorized page:
  rescue_from CanCan::AccessDenied do |exception|
    name =
      if user_signed_in?
        user = current_user
        "User #{user.display_name.inspect} (#{user.id})"
      else
        "Unlogged-in user"
      end
    logger.debug "#{name} is unauthorized: "+exception.message  #  user.id is also activated (by Cancancan?)
    redirect_to root_url
  end

  # authorize_resource :class => false

  # Exception handling when tyring to get ApplicationGrid.new(grid_params)  
  # e.g., ActiveModel::UnknownAttributeError (unknown attribute 'created_at' for Harami1129sGrid.)
  rescue_from ActiveModel::UnknownAttributeError do
    logger.error 'params that caused Error: '+params.inspect
    # render :nothing => true, :status => :bad_request  # does not work
    render :file => Rails.root.to_s+"/public/400.html", :status => :bad_request # 400
    #raise ActiveRecord::RecordNotFound  # 404
    # head 400  # => blank page (Rails 5)
  end

  # Expected returned String from the form interface
  #
  # For String, this is obvious. For true/false, the string is returned.
  # For nil, "on" is returned.
  #
  # @param val [Object] given value from Rails to Form
  # @return [String]
  def self.returned_str_from_form(val)
    case val
    when nil
      "ok"
    else  # including true, false
      val.to_s
    end
  end

  # Retrieve an translation from params and add it to the model (for Place, Artist, etc)
  #
  # The contents of the given model are modified.
  #
  # In default, +is_orig+ is forced to be true! (unless force_is_orig_true is given false and is_orig is included in params)
  # This is so because the +is_orig+ choice is not given to the user in create in UI.
  #
  # Note that although a Translation is almost always associated as an unsaved_translation to
  # the original instance, there is no guarantee that the Translation is valid.
  # As an extreme case (which should never happen via U/I), if the given langcode in params
  # is nil, the Translation is automatically invalid.
  #
  # @example
  #   hsmain = params[:place].slice('note')
  #   @place = Place.new(**(hsmain.merge({prefecture_id: params[:place][:prefecture].to_i})))
  #   add_unsaved_trans_to_model(@place)
  #
  # @param mdl [ApplicationRecord]
  # @param prms [ActionController::Parameters, Hash] 1-layer Hash-like object. All parameters must be permitted.
  # @param force_is_orig_true: [Boolean] if true (Def), +is_orig+ is forced to be true!
  # @return [void]
  def add_unsaved_trans_to_model(mdl, prms=nil, force_is_orig_true: true)
    mdl_name = mdl.class.name
    prms ||= params[mdl_name.underscore]  # e.g., params["event_group"]
    begin
      hsprm_tra = prms.slice(*PARAMS_TRANS_KEYS).to_h.with_indifferent_access
      # If this raises ActionController::UnfilteredParameters, you may want to exlicitly specify the *permitted* prms
    rescue NoMethodError => err
      logger.error("ERROR(#{File.basename __FILE__}): params['#{mdl_name.downcase}'] seems not correct: params=#{params.inspect}")
      raise
    end
    hsprm_tra[:translatable_type] = mdl_name
    hsprm_tra[:is_orig] =
      if force_is_orig_true || !hsprm_tra.has_key?("best_translation_is_orig")
        true
      else
        convert_param_bool hsprm_tra[:best_translation_is_orig]
      end
    tra = Translation.preprocessed_new(**(hsprm_tra.slice(*Translation.attribute_names)))

    mdl.unsaved_translations << tra
  end

  # Default respond_to to format algorithm
  #
  # If the block is given, it should include a save-attempt.
  # For alert/warning etc messages, you can specify a Proc
  # that takesthe model instance as an argument, which will
  # be evaluated after save.
  #
  # Also, this method properly evaluates +String#html_safe+
  # for flash messages. So, you can pass HTML messages to flash
  # by converting it +html_safe+, like
  #   def_respond_to_format(@article, notice: "<b>My</b> notice".html_safe)
  # Or, this method also consider flash messeages for :notice and :warning.
  #
  # See /app/views/layouts/application.html.erb for implementation in View.
  #
  # @example create
  #   def_respond_to_format(@article)  # defined in application_controller.rb
  #
  # @example update
  #   def_respond_to_format(@page_format, :updated){ 
  #     @page_format.update(page_format_params)
  #   } # defined in application_controller.rb
  #
  # @example update with Proc (mdl is evaluated after @prefecture.update)
  #   opts = { failed: false,
  #            warning: Proc.new{|mdl|
  #              get_created_warning_msg(mdl, :update, extra_note: " in Japan")}
  #          }
  #   def_respond_to_format(@prefecture, :updated, **opts){
  #     @prefecture.update(prefecture_params)
  #   } # defined in application_controller.rb
  #
  # @param mdl [ApplicationRecord]
  # @param created_updated [Symbol] Either :created(Def) or :updated
  # @param failed [Boolean] if true (Def: false), it has already failed.
  # @param redirected_path [String, NilClass] Path to be redirected if successful, or nil (Default)
  # @param render_err_path [String, NilClass] If non-nil, the path is used for rendering, e.g., "musics/merges" => "musics/merges/(new|edit)" 
  # @param force_redirect [Boolean] In default (false), if save/update fails, this tries to render a page, the path of which depends on +created_updated+ and +render_err_path+ (if specified). However, if this is set true and in case of failure, this redirects to +render_err_path+, which should be the exact path.
  # @param back_html [String, NilClass] If the path specified (Def: nil) and if successful, HTML (likely a link to return) preceded with "Return to" is added to a Flash mesage; e.g., '<a href="/musics/5">Music</a>'
  # @param alert [String, NilClass] alert message if any
  # @param warning [String, NilClass] warning message if any
  # @param notice [String, NilClass] notice message if any
  # @param success [String, NilClass] success message if any. Default is "%s was successfully %s." but it is overwritten if specified.
  # @return [Boolean, NilClass] true value if successfully saved.
  # @yield [] If given, this is called instead of simple @model.save
  def def_respond_to_format(mdl, created_updated=:created, failed: false, redirected_path: nil, render_err_path: nil, force_redirect: false, back_html: nil, alert: nil, **inopts)
    raise ArgumentError, "ERROR(#{__method__}): When force_redirect is true, render_err_path must be specified, too. Contact the code developer." if force_redirect && render_err_path.blank?
    ret_status, render_err =
      case created_updated.to_sym
      when :created
        [:created, (render_err_path ? render_err_path+"/new" : :new)]
      when :updated
        [:ok,      (render_err_path ? render_err_path+"/edit" : :edit)]
      else
        raise 'Contact the code developer.'
      end

    result = nil
    result =
      if mdl.errors.any?
        false
      else
        (!failed && (block_given? ? yield : mdl.save))
      end
    inopts = inopts.map{|k,v| [k, (v.respond_to?(:call) ? v.call(mdl) : v)]}.to_h
    alert = (alert.respond_to?(:call) ? alert.call(mdl) : alert)
    hsflash = {}
    %i(warning notice).each do |ek|
      hsflash[ek] = flash[ek] if flash[ek].present?
    end
    hsflash.merge! inopts

    respond_to do |format|
      if result
        msg = sprintf '%s was successfully %s.', mdl.class.name, created_updated.to_s  # e.g., Article was successfully created.
        msg << sprintf('  Return to %s.', back_html) if back_html
        opts = get_html_safe_flash_hash(success: msg.html_safe, alert: alert, **hsflash)
        format.html { redirect_to (redirected_path || mdl), **opts }
        format.json { render :show, status: ret_status, location: mdl }
      else
        mdl.errors.add :base, alert if alert.present? # alert is, if present, included in the instance
        opts = get_html_safe_flash_hash(alert: alert, **hsflash)
        opts.delete :alert  # because alert is contained in the model itself.
        hsstatus = {status: :unprocessable_content}
        format.html { render render_err,       **(hsstatus.merge opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: mdl.errors, **hsstatus }
      end
    end
    result
  end


  # Default respond_to to format algorithm for destroy
  #
  # This returns (redirects) to the original URI unless the original one
  # is a path for the destroyed record, in which case +fallback_location+
  # is used whose default is Index.
  #
  # Note the one generated by scaffold is imperfect (it ignores an error in destroy).
  #
  # @example 
  #   def_respond_to_format_destroy(@event)
  #
  # @param mdl [ApplicationRecord]
  # @param destructive: [Boolean] if true (Def), +destroy!+ is used.
  # @param fallback_location: [String, NilClass] in default, index
  # @return [void]
  def def_respond_to_format_destroy(mdl, destructive: true, fallback_location: nil)
    self_urls = %i(show edit).map{|em|
      URI(helpers.url_for(controller: mdl.class.table_name, action: em, id: mdl, host: request.host_with_port))
    }

    if (destructive && mdl.destroy!) || mdl.destroy
      hsopt = {notice: "#{mdl.class.name} was successfully destroyed."}
      fmt_json = Proc.new { head :no_content }
    else
      hsopt = {status: :unprocessable_content}  # alert is contained in the model
      fmt_json = Proc.new { render json: mdl.errors, **hsopt }
    end

    respond_to do |format|
      fallback_location ||= helpers.url_for(controller: mdl.class.table_name, action: :index, only_path: true)
      if (u=request.referrer) && (uref=URI(u)) && self_urls.any?{|eurl| [:host, :port, :path].all?{|em| uref.send(em) == eurl.send(em)}}
        # Back to Index because Show page does not exist anymore.
        format.html { redirect_to fallback_location, **hsopt }
      else
        format.html { redirect_back fallback_location: fallback_location, **hsopt }
      end
      format.json(&fmt_json)
    end
  end

  # For Event and EventItem Controllers
  #
  # @param mdl [ApplicationRecord] Either Event or EventItem
  # @return [void]
  # @see #event_update_to_format
  def event_create_to_format(mdl)
    set_start_err_from_form(mdl)  # defined in module_common.rb

    # @hstra is set in set_hsparams_main_tra ; for EventItem, @hstra should be undefined.
    add_unsaved_trans_to_model(mdl, @hstra) if @hstra && @hstra.respond_to?(:has_key?) && @hstra.has_key?("title")
    def_respond_to_format(mdl)
    transfer_error_to_form(mdl, mdl_attr: :start_time_err, form_attr: :form_start_err)
  end

  # For Event and EventItem Controllers
  #
  # @param mdl [ApplicationRecord] Either Event or EventItem
  # @return [void]
  # @see #event_create_to_format
  def event_update_to_format(mdl)
    start_err = set_start_err_from_form(@hsmain, with_model: false)  # defined in module_common.rb
    def_respond_to_format(mdl, :updated){
      mdl.update(@hsmain.merge({start_time_err: start_err}))  # @hsmain is set in set_hsparams_main
    }
    transfer_error_to_form(mdl, mdl_attr: :start_time_err, form_attr: :form_start_err)
  end

  # Returns Hash of flashes to pass in respond_to so they can be displayed as HTML
  #
  # @see make_flash_html_safe!
  #
  # The argument is basically a Hash, which may contain arbitrary keys
  # including (though not limited to) +:alert+, +:notice+ etc, the values
  # of which are either String or Array (or nil).
  #
  # @param inopts [Hash] {alert: "xxx"} etc.
  # @return [Hash] in the same structure as the input +inopts+ except {flash: {alert: true, ...}} is added.
  def get_html_safe_flash_hash(**inopts)
    opts = { flash: {} }.merge(inopts)
    opts[:flash][:html_safe] ||= {}
    FLASH_CSS_CLASSES.each_key do |ek|  # perhasp %i(alert warning notice success)
      eksym = ek.to_sym
      opts[:flash][:html_safe][eksym] = true if _all_html_safe?(opts[eksym])
    end
    opts
  end

  # Returns true if all the element of obj is html_safe? regardless of its object class
  #
  # @param obj [String, Array, NilClass]
  def _all_html_safe?(obj)
    if obj.blank?
      false
    elsif obj.respond_to?(:gsub)
      obj.html_safe?
    else
      obj.all?(&:html_safe?)
    end
  end
  private :_all_html_safe?

  # Make flash messages in Hash html_safe, maybe by escaping, and set them ready to be displayed as HTML
  #
  # Escapes all html-unsafe flash messages, converting them HTML-safe,
  # and mark all flash messages as HTML-safe so that links etc are properly displayed.
  #
  # In fact, for `respond_to`, `get_html_safe_flash_hash` should be used;
  # for this reason, this method has not been used so far, or not been tested, either!
  #
  # == Algorithm
  #
  # Escape all HTML-unsafe messages, replacing the original flash messages, if required.
  # Also, +flash[:html_safe][:notice]+ etc are set true, which can then be handled in
  # Views (see /app/views/layouts/application.html.erb), where +html_safe+ has to be
  # reassigned (because exact Ruby objects are not passed to them).
  #
  # @note This method should be called immediately before it is passed to the next Session.
  #    because this method's marking entirely depends on the current flash messages.
  #    If an unsafe flash message is added after this method is run, it is a security risk.
  def make_flash_html_safe!(flash_classes=FLASH_CSS_CLASSES.keys)
    flash[:html_safe] ||= {}
    flash_classes.each do |ek_orig|
      ek_sym = ek_orig.to_sym
      next if flash[ek_sym].blank?
      if flash[ek_sym].respond_to?(:gsub)
        flash[ek_sym] = ERB::Util.html_escape(flash[ek_sym]) if !flash[ek_sym].html_safe?
      elsif flash[ek_sym].respond_to?(:map)
        flash[ek_sym].each_with_index do |ea_msg, i|
          flash[ek_sym][i] = ERB::Util.html_escape(ea_msg) if !ea_msg.html_safe?
        end
      else
        raise "Flash for #{ek_sym.inspect} is neither String nor Array: #{flash[ek_sym].inspect}"
      end

      flash[:html_safe][ek_sym] = true
    end
    flash
  end

  # Returns either :show or :index path to return, or nil
  #
  # Based on the form/model parameters of {#prev_model_name} and {#prev_model_id}
  #
  # IF THIS WAS PLACED in /app/helpers/application_helper.rb and if it is called
  # from inside a Controller, you would need to call this like
  #    view_context.prev_redirect_str()
  #
  # In a +new+ page, e.g., +new_place_url+, write in the ERB view:
  #   <%= hidden_field(:place, :prev_model_name) %>
  # This will be passed to +params+ as
  #   params[:place]["place_prev_model_name"]
  # (Notice the prefix +place_+)
  # Then, in +PlacesController+, you can set
  #   @place.prev_model_name = params.require(:place).permit("place_prev_model_name")["place_prev_model_name"]
  #
  # @example PlacesController
  #    prev_redirect_url(@place)
  #    # => /musics     (if @place.prev_model_name == 'music')
  #    # => /music/123  (if @place.prev_model_id == 123)
  #
  # @param mdl [ActiveRecord]
  # @param get_link [Boolean] if true (Def: false), return an HTML containing a link (assuming the same HOST).
  # @param langcode [String, NilClass] for HTML-link label
  # @return [String, NilClass] the path to redirect or nil
  # @see https://stackoverflow.com/questions/74256169/how-to-get-rails-path-url-dinamically-from-a-model-controller/74256692  (for url_for)
  def prev_redirect_str(mdl, get_link: false, langcode: nil)
    return if mdl.prev_model_name.blank?
    opts = { controller: mdl.prev_model_name.underscore.pluralize, only_path: true }
    if mdl.prev_model_id.blank?
      path = url_for(action: :index, **opts)
      get_link ? view_context.link_to(sprintf("%s index", mdl.prev_model_name), path) : path
    else
      path = url_for(action: :show, id: mdl.prev_model_id.to_i, **opts)
      return path if !get_link
      lang = (langcode || I18n.locale).to_s
      my_title = mdl.prev_model_name.constantize.find(mdl.prev_model_id.to_i).title_or_alt(langcode: lang)
      sprintf "%s (%s)", mdl.prev_model_name, view_context.link_to(my_title, path).html_safe
    end
  end

  # Returns a warning message, if there is difference between original and updated
  #
  # @param mdl [ApplicationRecord] a model instance
  # @param created_updated [Symbol] Either :created(Def) or :updated
  # @param excepts [Array] Symbols of the model attribute that are exempts of the warning
  # @param extra_note [String, NilClass] e.g., " in Japan" (make sure it precedes with a space)
  # @return [String, NilClass] nil if no differences are found.
  def get_created_warning_msg(mdl, created_updated=:created, excepts: [], extra_note: "")
    hsdiff = mdl.saved_changes.slice!(:updated_at, *excepts)
    return if hsdiff.empty?
    sprintf(
      "Object %s for %s(ID=%s)%s. Make sure that is what you intended: %s",
      created_updated.to_s,
      mdl.class.name,
      mdl.id.inspect,
      extra_note.to_s,
      hsdiff.inspect
    )
  end

  # Set three instance variables @hsmain, @prms_all and @hstra
  #
  # See {#set_hsparams_main} for detail.  In addition, this sets 
  #
  # * @hstra  (for common translation-related parameters for +create+).
  #
  # @note +action_name+ (+create+ ?) is checked inside because the translation-related
  #  parameters are relevant only for (+create+)!
  #
  # @param model_name [String, Symbol] model name like "event_group"
  # @return [ActionController::Parameters, Hash] all permitted params
  def set_hsparams_main_tra(model_name, array_keys: [])
    additional_keys = ((:create == action_name.to_sym) ? PARAMS_TRANS_KEYS : [])  # latter defined in application_controller.rb
    set_hsparams_main(model_name, additional_keys: additional_keys, array_keys: array_keys)
    @hstra = @prms_all.slice(*PARAMS_TRANS_KEYS).to_h  # defined in application_controller.rb
    @prms_all
  end

  # Ensures minimum Translation-related parameters exist (on create)
  #
  # This is usually put in the "create" in Controller
  #
  # When +check_title_presence+ is true, this raises ActionController::ParameterMissing
  # if neither of title and alt_title exist.  Usually, it should be dealt in a different way
  # from Ruby-level exception, though (hence its default being false).
  #
  # @example ensure_trans_exists_in_params("engage_how")  # defined in application_controller.rb
  #
  # @raise ActionController::ParameterMissing
  def ensure_trans_exists_in_params(mdl_name, check_title_presence: false)
    mdl_name = mdl_name.class.name if !mdl_name.respond_to?(:to_sym)
    mdl_name_us = mdl_name.to_s.underscore

    params.require(mdl_name_us).require(:langcode)
    params.require(mdl_name_us).require(:title) if check_title_presence && params[mdl_name_us][:alt_title].blank?
  end


  # Set two instance variables @hsmain and @prms_all 
  #
  # Only allows a list of trusted parameters through and
  # sets Hash-es of
  #
  # * @hsmain (for model-specific parameters) and
  # * @prms_all (ActionController::Parameters / includin all parameters permitted under the model, e.g., params[:music]).  Those in multiple layers are not permitted.
  #
  # The caller Controler should define 2 or 3 (and 1 more optional) Array constants of Symbols:
  #
  # * +PARAMS_MAIN_KEYS+: The attributes input in the form that agree with the form keywords
  # * +MAIN_FORM_KEYS+: The form keywords that do not exist in the attributes like :is_this_form_used
  # * +PARAMS_ARRAY_KEYS+: Key for a 1-level nested Array in params, eg., +{music: {..., engage_hows: [1,2,3]}}+.  This key **must** exist in either of the above Array constants.
  # * +MAIN_FORM_BOOL_KEYS+: (optional) List of keys for which the attributes should be converted into a boolean or nil (from "0", "1", "", or true, "true" etc; the latters may appear in testing). Ideally, Controllers should call {#convert_param_bool} to get a boolean value and Controller-test scripts should call get_params_from_bool (defiend in test_helper.rb) for the reverse action, but we may forget...
  #
  # @param model_name [String, Symbol] model name like "event_group"
  # @param additional_keys: [Array<Symbol>] Additional keys (usually Translation related used by {#set_hsparams_main_tra})
  # @return [ActionController::Parameters, Hash] all permitted params
  def set_hsparams_main(model_name, additional_keys: [], array_keys: [])
    if !self.class.const_defined?(:PARAMS_MAIN_KEYS)
      raise NameError, "uninitialized constant #{self.class.name}::PARAMS_MAIN_KEYS -- you must define it and MAIN_FORM_KEYS in the controller!"
    end
    allkeys = self.class::PARAMS_MAIN_KEYS + additional_keys
    hs_array_keys = array_keys.map{|i| [i, []]}.to_h

    if (self.class.const_defined?(:PARAMS_ARRAY_KEYS) && ary=self.class::PARAMS_ARRAY_KEYS)  # nested params
      allkeys = allkeys.map{|ek| ary.include?(ek) ? {ek => []} : ek}
    end

    hsall = params.require(model_name).permit(*allkeys, **hs_array_keys)
    @hsmain = hsall.slice(*(self.class::MAIN_FORM_KEYS)).to_h  # nb, "place.prefecture_id" is ignored.
    @hsmain[:place_id] = helpers.get_place_from_params(hsall).id if !allkeys.map{|ek| ek.respond_to?(:to_sym) ? ek.to_sym : nil}.map(&:to_s).grep(/\Aplace(_id)?\z/).empty? #.include?(:place_id)   # Modified (overwritten)  # defined in application_helper.rb
    if self.class.const_defined?(:MAIN_FORM_BOOL_KEYS)
      self.class::MAIN_FORM_BOOL_KEYS.each do |ek|
        next if !@hsmain.has_key?(ek)
        @hsmain[ek] = convert_param_bool(@hsmain[ek], true_int: 1)
      end
    end
    @prms_all = hsall
  end

  # Retunrs a hash where boolean (and nil) values in the specified keys are converetd from String to true/false/nil
  #
  # Note so far this handles only a 1-layer Hash.
  #
  # @param hash [Hash]
  # @param *keys [Array<Symbol,String>]
  # @param **opts [Hash] specify true_int (see {#convert_param_bool})
  # @return [Hash]
  def convert_params_bool(hash, *keys, **opts)
    reths = hash.dup
    keys.each do |ek|
      raise ArgumentError, "(#{File.basename __FILE__}) key=#{ek} not exists. Contact the code developer." if !reths.has_key? ek
      reths[ek] =
        convert_param_bool(reths[ek], **opts)
    end
    reths
  end

  # Core routine of {#convert_params_bool}
  #
  # For a checkbox, a form returns "1" when checked. Therefore, true_int is usually "1" (!!).  So, you should explicitly specify true_int!
  # My reverse method +get_params_from_bool+ defined in test_helper.rb defines it so, indeed.
  #
  # @param val [String, NilClass]
  # @param true_int: [Integer] Integer meaning true
  # @return [Boolean, Nilclass]
  def convert_param_bool(val, true_int: 0)
    false_int_str = ((true_int == 0) ? '1' : '0')
    val = val.downcase if val.respond_to?(:downcase)
    case val
    when 'true', true, true_int.to_s, self.class.returned_str_from_form(true)
      true
    when 'false', false, false_int_str, self.class.returned_str_from_form(true)
      false
    when 'nil', 'on', nil, "", self.class.returned_str_from_form(FORM_TERNARY_UNDEFINED_VALUE)  # if nil is specified in radio_button in html.erb, 'on' is returned.
      nil
    else
      raise "ERROR(#{__method__}): unexpected input (#{val.inspect})"
    end
  end

  # Returns a Hash#compact-ed Hash with keys of Symbols and String#strip-ped values
  #
  # @return [Hash]
  def stripped_params(params)
    params.to_h.strip_strings.values_blank_to_nil.compact.with_sym_keys # defined in ModuleHashExtra
  end

  # create start/end_date from 3 parameters
  #
  # year etc may be String.
  #
  # If err is nil and if day or month is blank, a middle day is set
  # (like 2 July if month is nil) and an appropriate error is set
  # in the returned TimeWithError as defined in +/lib/time_with_error.rb+
  #
  # @param err: [Integer, String, NilClass] Integer-like
  # @return [TimeWithError, NilClass]
  def self.create_a_date(year, month, day, err: nil)
    ar = [year, month, day].map{|i| convert_str_to_number_nil(i)}
    return nil if ar.compact.empty?
    if err.present?
      t = TimeWithError.new(*ar, in: Rails.configuration.music_i18n_def_timezone_str)
      t.error = err.to_i.day
      t
    else
      TimeAux.converted_middle_time(*ar)  # This returns TimeWithError, as defined in /lib/time_with_error.rb
    end
  end

  # create start/end_time from 5 or 6 parameters
  #
  # year etc may be String.
  #
  # @param err: [ActiveSupport::Duration, Integer, String, NilClass] in second if Integer-like
  # @return [TimeWithError, NilClass] as defined in /lib/time_with_error.rb
  def self.create_a_time(year, month, day, hour, minute, second=nil, err: nil)
    ar = [year, month, day, hour, minute, second].map{|i| convert_str_to_number_nil(i)} # defined in ModuleCommon
    return nil if ar.compact.empty?
    return TimeAux.converted_middle_time(*ar) if err.blank?

    t = TimeWithError.new(*ar, in: Rails.configuration.music_i18n_def_timezone_str)
    t.error = (err.respond_to?(:in_seconds) ? err : err.to_i.second)
    t
  end

  # Sets (start|end)_date and (start|end)_date_err in Hash hsmain
  #
  # Overwrites the given +hsmain+
  #
  # @param prmall [ActionController::Parameters, Hash] all permitted params
  # @param hsmain [Hash] Main Hash from params for Object, excluding translation-related ones
  def _set_dates_to_hsmain(prmall, hsmain=@hsmain)
    %w(start end).each do |col_prefix|
      errcolname = col_prefix+"_date_err"
      err = prmall[errcolname]
      err = nil if err && err.strip.blank?

      ar = %w(year month day).map{|i| prmall[col_prefix+"_"+i].presence}
      hsmain[col_prefix+"_date"] = self.class.create_a_date(*ar, err: err)
      hsmain[errcolname] = err  # String. If not integer-like, validation in Conroller should catch it.
    end
  end

  # Sets start_time and start_time_err in Hash hsmain
  #
  # Overwrites the given +hsmain+
  #
  # @param prmall [ActionController::Parameters, Hash] all permitted params
  # @param hsmain [Hash] Main Hash from params for Object, excluding translation-related ones
  def _set_time_to_hsmain(prmall, hsmain=@hsmain)
    time_err = 
      if prmall[:start_err].blank?
        nil
      else
        unit = prmall[:start_err_unit].strip
        if EVENT_FORM_ERR_UNITS.to_h.values.include?(unit)
          prmall[:start_err].to_f.send(unit)
        else
          logger.warn "(#{File.basename(__FILE__)}) Invalid :start_err_unit is specified: #{prmall[:start_err_unit].inspect}"
          nil
        end
      end

    ar = %w(year month day hour minute).map{|i| prmall["start_"+i].presence}
    hsmain["start_time"]     = self.class.create_a_time(*ar, err: time_err)  # even if time_err is nil, hsmain["start_time"] may be set?? (e.g., if only Year is significant).
    hsmain["start_time_err"] = time_err
  end
  private :_set_time_to_hsmain


  # copy the error attribute so it can be handled by simple_form
  #
  # For example, errors[:start_time_err] is transferred (copied) to errors[:form_start_err]
  #
  # See {ModuleCommon#compile_captured_err_msg} (in case of Rails Exception)
  #
  # @param mdl [ApplicationRecord] like @event
  # @param mdl_attr: [String, Symbol] Attribute for which an error is raised (such as "not Numeric")
  # @param form_attr: [String, Symbol] Attribute used in the form
  def transfer_error_to_form(mdl, mdl_attr: :start_time_err, form_attr: :form_start_err)
    if !mdl.errors[mdl_attr].empty?
      mdl.errors[mdl_attr].each do |ea_msg|
        mdl.errors.add(form_attr, ea_msg)
        # TODO: remove the error(s) from errors[mdl_attr] (e.g., errors["start_time_err"])
      end
    end
  end

  # Grid-view form helper method
  #
  # @example in ERB
  #    <%= ApplicationController.str_info_entry_page_numbers(@grid, Translation) %>
  #    
  # @return [String]
  def self.str_info_entry_page_numbers(grid, klass)
    asset = grid.assets
    tot_count = asset.total_count
    cur_page = asset.current_page
    n_per_page = asset.limit_value
    ### NOTE: asset.size returns something like {1793=>49, 1728=>32, 1500=>31},
    #  where the SQL (in ordering) is grouped,
    #  where the Hash seems to mean ID=>count_number;
    #  in such a case, asset.inspect returns just #<ActiveRecord::Relation ...> as usual
    #  but I suppose its internal structure is different from non-grouped ones.
    #  Although the following seems to work, I don't understand exactly what is happening, so leave them for now...
#logger.warn("=============================[asset]="+asset.inspect)
#logger.warn("=============================[count]="+asset.count.inspect)
#logger.warn("=============================[cur_page, n_per_page, asset.size, tot]="+[cur_page, n_per_page, asset.size, tot_count].inspect)
    # n_selected_pages = [(cur_page-1)*n_per_page+asset.size, tot_count].min  # playing safe though it should be: ((cur_page-1)*n_per_page+asset.size == tot_count)
    asize = (asset.size.respond_to?(:size) ? asset.size.size : asset.size)
    # n_selected_pages = [(cur_page-1)*n_per_page+asize, tot_count].min  # playing safe though it should be: ((cur_page-1)*n_per_page+asset.size == tot_count)
    #### I didn't understand the statement above... Anyway the result was wrong in Url#index.  So I have modified it as follows:
    n_selected_pages = [cur_page*n_per_page, tot_count].min
  
    sprintf(
      "%s (%d—%d)/%d [%s: %d]",
      I18n.t("tables.Page_n", count: cur_page, default: "Page "+cur_page.to_s),
      [(cur_page-1)*n_per_page+1, n_selected_pages].min,  # maybe 0
      n_selected_pages,  
      tot_count,
      I18n.t("tables.grand_total_entries", default: "Grand total"),
      klass.count
    )
  end

  # params returns "ins_at(1i)", "ins_at(2i)" etc.  Returns the converted Date or Time.
  #
  # Current local time zone.
  #
  # @example
  #    date_or_time_from_params(my_model_params, "ins_at", is_date: false)  # defined in application_controller.rb
  #
  # @param hsprm [Parameters] Rails (filtered and permitted) Parameter Hash
  # @param kwd [String, Symbol] e.g., "published_date", "inserted_at"
  # @param is_date: [Boolean, NilClass] true for Date, false for Time. If nil, automatically judged from kwd.
  # @return [Time, Date]
  def date_or_time_from_params(hsprm, kwd, is_date: nil)
    is_date = (/_date$/ =~ kwd.to_s) if is_date.nil?
    str4parse = _build_str4parse(hsprm, kwd)
    return if !str4parse

    if is_date
      Date.parse(str4parse)
    else
      Time.zone.parse(str4parse)
    end
  end

  # Build String to be parsed by Date or Time
  #
  # @return [String, NilClass] nil if kwd is not found in hsprm or Year is blank.
  def _build_str4parse(hsprm, kwd)
    ar6 = Array.new(6)
    (1..6).each do |i_num|
      k = sprintf("%s(%di)", kwd.to_s, i_num)
      ar6[i_num-1] = hsprm[k] if hsprm.has_key?(k)
    end

    return if ar6[0].blank?  # If Year is blank, this means the date/time is not present in the first place.

    datepart = sprintf "%s-%s-%s", *ar6[0..2].map{|i| i ? i : "00"}
    return datepart if ar6[3..5].compact.empty?

    datepart + sprintf(" %s:%s:%s", *ar6[3..5].map{|i| i ? i : "00"})
  end
  private :_build_str4parse

  # Log an info message after create
  #
  # +extra_str+ is passed to {ApplicationRecord#logger_title} as the sole element of +extra+
  #
  # The information of the initiated user is {User#display_name} in Test environment, else ID.
  #
  # @example
  #    logger_after_create(@music, extra_str: " / Artists=#{ApplicationRecord.logger_titles(@music.artists.uniq)}", method_txt: __method__)  # defined in application_controller.rb
  #
  # @param model [ApplicationRecord]
  # @param extra_str: [String] see above
  # @param method_txt: [String] pass +__message__+
  # @param header_txt: [String] Def: "Created"
  # @return [void]
  def logger_after_create(model, extra_str: "", method_txt: "create", header_txt: "Created")
    model.logger_after_create(extra_str: extra_str, execute_class: self.class, method_txt: method_txt, header_txt: "Created", user: current_user)  # defined in application_record.rb
  end

  # Helper method to add a flash message
  #
  # @example
  #    add_flash_message(:warning, "Strange input")  # defined in application_controller.rb
  #
  # @param type [String, Symbol] :alert, :warning, :success, :notice
  # @param msg [String] Message to add
  # @return [Array] of flash of the type
  def add_flash_message(type, msg)
    raise "Wrong flash type of #{type.inspect}" if !FLASH_CSS_CLASSES.include?(type.to_s)
    flash[type.to_sym] ||= []
    flash[type.to_sym] << msg
    flash[type.to_sym]
  end

  ######################## Callbacks

  # Callback
  def set_translation_whodunnit
    ModuleWhodunnit.whodunnit = current_user
  end

  protected
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:display_name])
      devise_parameter_sanitizer.permit(:account_update, keys: [:display_name])
    end

    # around_action
    #
    # With this,
    #
    # 1. if /ja/places is requested, the internally-used locale is ja (Japanese).
    # 2. if /places is requested, the URL does not change, while
    #    the internally-used locale is set according to the user request
    #    determined with Gem http_accept_language (or site default if none is requested).
    # 3. The root paths (like "/" and "/ja") are correctly handled, too.
    #
    # From https://guides.rubyonrails.org/i18n.html#managing-the-locale-across-requests
    def switch_locale(&action)
      # locale = (params[:locale].blank? ? I18n.default_locale : params[:locale])
      locale = (params[:locale].blank? ? (http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale) : params[:locale])  # defined by Gem http_accept_language
      I18n.with_locale(locale, &action)
    end

    def set_countries
      @countries = 
        case I18n.locale.to_s
        when "ja"
          Country.sort_by_best_titles(countries_order_jp_top, prefer_alt: true)  # defined in ApplicationHelper
        else
          sql2order = sql_order_jp_top+", name_en_short"
          Country.left_joins(:country_master).order(Arel.sql(sql2order))
        end
      @prefectures = Prefecture.all
    end

    # To use +CURRENT_USER+ (instead of +current_user+) inside Grids
    #
    # @note Setting ApplicationGrid Class instance variable does not work well
    #   (it seems to be reset when the Class file is reread, though object_id unchanges...)
    def set_current_user_for_grid
      return if :destroy == action_name.to_sym  # emulating "except: [:destroy]"
      ApplicationGrid.send(:remove_const, :CURRENT_USER) if ApplicationGrid.const_defined?(:CURRENT_USER)  # because this may be called multiple times in tests or when cached.
      ApplicationGrid.const_set(:CURRENT_USER, current_user)
    end

    ## for DEBUG (corresponding to the commented calls above)
    #def debug_ctrl_print1
    #  puts ("DEBUG(#{File.basename __FILE__})(1:Before-everything): "+params.inspect)
    #  logger.debug("DEBUG(#{File.basename __FILE__})(1:Before-everything): "+params.inspect)
    #end
    #def debug_ctrl_print2
    #  logger.debug("DEBUG(#{File.basename __FILE__})(2:After-befo_action): "+params.inspect)
    #end
end

Devise::ParameterSanitizer::DEFAULT_PERMITTED_ATTRIBUTES[:sign_up] << :accept_terms
# see /vendor/bundle/ruby/*/gems/devise-*/lib/devise/parameter_sanitizer.rb

