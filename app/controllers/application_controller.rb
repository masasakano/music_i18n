# coding: utf-8
class ApplicationController < ActionController::Base
  include ModuleCommon   # for split_hash_with_keys() etc
  extend ModuleCommon    # for convert_str_to_number_nil
  using ModuleHashExtra  # for extra methods, e.g., Hash#values_blank_to_nil

  protect_from_forgery with: :exception

  ## Uncomment this (as well as the method below) to investigate problems related to params()
  #before_action :debug_ctrl_print1
  before_action :authenticate_user!

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_paper_trail_whodunnit
  before_action :set_translation_whodunnit
  before_action :set_current_user_for_grid, except: [:destroy]
  ## Uncomment this (as well as the method below) to investigate problems related to params()
  #before_action :debug_ctrl_print2

  around_action :switch_locale

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

  # Common params keys for {Translation}.
  # @note +:is_orig+ is not included!
  PARAMS_TRANS_KEYS = [:langcode, :title, :ruby, :romaji, :alt_title, :alt_ruby, :alt_romaji]  # :is_orig

  # Common params keys for {Place}.
  PARAMS_PLACE_KEYS = %i(place.prefecture_id.country_id place.prefecture_id place place_id)  # :place is used (place_id seems redundant(?) but the most basic UI may require it and so we leave it)

  # Unit used in Event/EventItem Forms
  EVENT_FORM_ERR_UNITS = [["days", "day"], ["hours", "hour"], ["minutes", "minute"]]

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

  # Exception handling when tyring to get BaseGrid.new(grid_params)  
  # e.g., ActiveModel::UnknownAttributeError (unknown attribute 'created_at' for Harami1129sGrid.)
  rescue_from ActiveModel::UnknownAttributeError do
    logger.error 'params that caused Error: '+params.inspect
    # render :nothing => true, :status => :bad_request  # does not work
    render :file => Rails.root.to_s+"/public/400.html", :status => :bad_request # 400
    #raise ActiveRecord::RecordNotFound  # 404
    # head 400  # => blank page (Rails 5)
  end

  # Retrieve an translation from params and add it to the model (for Place, Artist, etc)
  #
  # The contents of the given model are modified.
  #
  # `is_orig` is forced to be true!
  #
  # @example
  #   hsmain = params[:place].slice('note')
  #   @place = Place.new(**(hsmain.merge({prefecture_id: params[:place][:prefecture].to_i})))
  #   add_unsaved_trans_to_model(@place)
  #
  # @param mdl [ApplicationRecord]
  # @param prms [ActionController::Parameters, Hash] 1-layer Hash-like object. All parameters must be permitted.
  # @return [void]
  def add_unsaved_trans_to_model(mdl, prms=nil)
    mdl_name = mdl.class.name
    prms ||= params[mdl_name.underscore]  # e.g., params["event_group"]
    begin
      hsprm_tra = prms.slice(*PARAMS_TRANS_KEYS).to_h
      # If this raises ActionController::UnfilteredParameters, you may want to exlicitly specify the *permitted* prms
    rescue NoMethodError => err
      logger.error("ERROR(#{File.basename __FILE__}): params['#{mdl_name.downcase}'] seems not correct: params=#{params.inspect}")
      raise
    end
    tra = Translation.preprocessed_new(**(hsprm_tra.merge({is_orig: true, translatable_type: mdl_name})))

    mdl.unsaved_translations << tra
  end

  # Default respond_to to format algorithm
  #
  # If the block is given, it should include a save-attempt.
  # For alert/warning etc messages, you can specify a Proc
  # that takesthe model instance as an argument, which will
  # be evaluated after save.
  #
  # Also, this routine properly evaluates +String#html_safe+
  # for flash messages. So, you can pass HTML messages to flash
  # by converting it +html_safe+, like
  #   def_respond_to_format(@article, notice: "My notice".html_safe)
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
  # @param back_html [String, NilClass] If the path specified (Def: nil) and if successful, HTML (likely a link to return) preceded with "Return to" is added to a Flash mesage; e.g., '<a href="/musics/5">Music</a>'
  # @param alert [String, NilClass] alert message if any
  # @param warning [String, NilClass] warning message if any
  # @param notice [String, NilClass] notice message if any
  # @param success [String, NilClass] success message if any. Default is "%s was successfully %s." but it is overwritten if specified.
  # @return [void]
  # @yield [] If given, this is called instead of simple @model.save
  def def_respond_to_format(mdl, created_updated=:created, failed: false, redirected_path: nil, back_html: nil, alert: nil, **inopts)
    ret_status, render_err =
      case created_updated.to_sym
      when :created
        [:created, :new]
      when :updated
        [:ok, :edit]
      else
        raise 'Contact the code developer.'
      end

    respond_to do |format|
      result = (!failed && (block_given? ? yield : mdl.save))
      inopts = inopts.map{|k,v| [k, (v.respond_to?(:call) ? v.call(mdl) : v)]}.to_h
      alert = (alert.respond_to?(:call) ? alert.call(mdl) : alert)
      if result
        msg = sprintf '%s was successfully %s.', mdl.class.name, created_updated.to_s  # e.g., Article was successfully created.
        msg << sprintf('  Return to %s.', back_html) if back_html
        #opts = { success: msg.html_safe, flash: {}}.merge(inopts) # "success" defined in /app/controllers/application_controller.rb
        opts = flash_html_safe(success: msg.html_safe, alert: alert, **inopts)
        #opts[:alert]  = alert if alert
        #opts[:flash][:html_safe] ||= {}
        #%i(alert warning notice success).each do |ek|
        #  opts[:flash][:html_safe][ek] = true if opts[ek].html_safe?
        #end
        format.html { redirect_to (redirected_path || mdl), **opts }
        format.json { render :show, status: ret_status, location: mdl }
      else
        mdl.errors.add :base, alert  # alert is included in the instance
        opts = flash_html_safe(alert: alert, **inopts)
        opts.delete :alert  # because alert is contained in the model itself.
        hsstatus = {status: :unprocessable_entity}
        format.html { render render_err,       **(hsstatus.merge opts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: mdl.errors, **hsstatus }
      end
    end
  end


  # Default respond_to to format algorithm for destroy
  #
  # This returns (redirects) to the original URI unless the original one
  # is a path for the destroyed record.
  #
  # Note the one generated by scaffold is imperfect (it ignores an error in destroy).
  #
  # @example 
  #   def_respond_to_format_destroy(@event)
  #
  # @param mdl [ApplicationRecord]
  # @param destructive [Boolean] if true (Def), +destroy!+ is used.
  # @return [void]
  def def_respond_to_format_destroy(mdl, destructive: true)
    self_urls = %i(show edit).map{|em|
      URI(helpers.url_for(controller: mdl.class.table_name, action: em, id: mdl, host: request.host_with_port))
    }

    if (destructive && mdl.destroy!) || mdl.destroy
      hsopt = {notice: "#{mdl.class.name} was successfully destroyed."}
      fmt_json = Proc.new { head :no_content }
    else
      hsopt = {status: :unprocessable_entity}  # alert is contained in the model
      fmt_json = Proc.new { render json: mdl.errors, **hsopt }
    end

    respond_to do |format|
      path_index = helpers.url_for(controller: mdl.class.table_name, action: :index, only_path: true)
      if (u=request.referrer) && (uref=URI(u)) && self_urls.any?{|eurl| [:host, :port, :path].all?{|em| uref.send(em) == eurl.send(em)}}
        # Back to Index because Show page does not exist anymore.
        format.html { redirect_to path_index, **hsopt }
      else
        format.html { redirect_back fallback_location: path_index, **hsopt }
      end
      format.json(&fmt_json)
    end
  end


  # Make flash messages in Hash html_safe if they are already so.
  #
  # Basically, this defines
  #   { flash: {html_safe: {alert: true, notice: false}} }
  # where +false+ is not explicitly defined in this routine,
  # i.e., if they are not html_safe, they are not set in the Hash
  # in this routine (i.e., the input Hash is unchanged).
  #
  # In View (/app/views/layouts/application.html.erb),
  #   flash[:html_safe][...]
  # is evaluated and +html_safe+ will be added on the spot if so.
  #
  # The argument is basically a Hash, which may contain arbitrary keys
  # including (though not limited to) +:alert+, +:notice+ etc.
  #
  # @return [Hash]
  def flash_html_safe(**inopts)
    opts = { flash: {} }.merge(inopts)
    opts[:flash][:html_safe] ||= {}
    %i(alert warning notice success).each do |ek|
      opts[:flash][:html_safe][ek] = true if opts[ek].html_safe?
    end
    opts
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
  def set_hsparams_main_tra(model_name)
    additional_keys = ((:create == action_name.to_sym) ? PARAMS_TRANS_KEYS : [])  # latter defined in application_controller.rb
    set_hsparams_main(model_name, additional_keys: additional_keys)
    @hstra = @prms_all.slice(*PARAMS_TRANS_KEYS).to_h  # defined in application_controller.rb
    @prms_all
  end

  # Set two instance variables @hsmain and @prms_all 
  #
  # Only allows a list of trusted parameters through and
  # sets Hash-es of
  #
  # * @hsmain (for model-specific parameters) and
  # * @prms_all (ActionController::Parameters / includin all parameters permitted under the model, e.g., params[:music]).  Those in multiple layers are not permitted.
  #
  # The caller Controler should define 2 or 3 Array constants of Symbols:
  #
  # * +PARAMS_MAIN_KEYS+: The attributes input in the form that agree with the form keywords
  # * +MAIN_FORM_KEYS+: The form keywords that do not exist in the attributes like :is_this_form_used
  # * +PARAMS_ARRAY_KEYS+: Key for a 1-level nested Array in params, eg., +{music: {..., engage_hows: [1,2,3]}}+.  This key **must** exist in either of the above Array constants.
  #
  # @param model_name [String, Symbol] model name like "event_group"
  # @param additional_keys: [Array<Symbol>] Additional keys (usually Translation related used by {#set_hsparams_main_tra})
  # @return [ActionController::Parameters, Hash] all permitted params
  def set_hsparams_main(model_name, additional_keys: [])
    allkeys = self.class::PARAMS_MAIN_KEYS + additional_keys

    if (self.class.const_defined?(:PARAMS_ARRAY_KEYS) && ary=self.class::PARAMS_ARRAY_KEYS)  # nested params
      allkeys = allkeys.map{|ek| ary.include?(ek) ? {ek => []} : ek}
    end

    hsall = params.require(model_name).permit(*allkeys)
    @hsmain = hsall.slice(*(self.class::MAIN_FORM_KEYS)).to_h  # nb, "place.prefecture_id" is ignored.
    @hsmain[:place_id] = helpers.get_place_from_params(hsall).id if allkeys.map{|ek| ek.respond_to?(:to_sym) ? ek.to_sym : nil}.include?(:place_id)   # Modified (overwritten)
    @prms_all = hsall
  end

  # Retunrs a hash where boolean (and nil) values in the specified keys are converetd from String to true/false/nil
  #
  # Note so far this handles only a 1-layer Hash.
  #
  # @param hash [Hash]
  # @param *keys [Array<Symbol,String>]
  # @return [Hash]
  def convert_params_bool(hash, *keys)
    reths = hash.dup
    keys.each do |ek|
      raise ArgumentError, "(#{File.basename __FILE__}) key=#{ek} not exists. Contact the code developer." if !reths.has_key? ek
      reths[ek] =
        case reths[ek]
        when 'true', true
          true
        when 'false', false
          false
        when 'nil', 'on', nil  # if nil is specified in radio_button in html.erb, 'on' is returned.
          nil
        else
        end
    end
    reths
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
    n_selected_pages = [(cur_page-1)*n_per_page+asset.size, tot_count].min  # playing safe though it should be: ((cur_page-1)*n_per_page+asset.size == tot_count)
  
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

  # Callback
  def set_translation_whodunnit
    Translation.whodunnit = current_user
  end

  protected
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:display_name])
      devise_parameter_sanitizer.permit(:account_update, keys: [:display_name])
    end

    # From https://guides.rubyonrails.org/i18n.html#managing-the-locale-across-requests
    def switch_locale(&action)
      locale = (params[:locale].blank? ? I18n.default_locale : params[:locale])
      I18n.with_locale(locale, &action)
    end

    def set_countries
      sql = "CASE countries.id WHEN #{Country.unknown.id rescue 9} THEN 0 WHEN #{Country['JP'].id rescue 9} THEN 1 ELSE 9 END, name_en_short"
      @countries = Country.left_joins(:country_master).order(Arel.sql(sql))
      @prefectures = Prefecture.all
    end

    # To use +CURRENT_USER+ (instead of +current_user+) inside Grids
    #
    def set_current_user_for_grid
      BaseGrid.send(:remove_const, :CURRENT_USER) if BaseGrid.const_defined?(:CURRENT_USER)  # because this may be called multiple times in (only) tests
      BaseGrid.const_set(:CURRENT_USER, current_user)
    end

    ## for DEBUG (corresponding to the commented calls above)
    #def debug_ctrl_print1
    #  logger.debug("DEBUG(#{File.basename __FILE__})(1:Before-everything): "+params.inspect)
    #end
    #def debug_ctrl_print2
    #  logger.debug("DEBUG(#{File.basename __FILE__})(2:After-befo_action): "+params.inspect)
    #end
end

Devise::ParameterSanitizer::DEFAULT_PERMITTED_ATTRIBUTES[:sign_up] << :accept_terms
# see /vendor/bundle/ruby/*/gems/devise-*/lib/devise/parameter_sanitizer.rb

