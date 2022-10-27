class ApplicationController < ActionController::Base
  include ModuleCommon   # for split_hash_with_keys() etc
  using ModuleHashExtra  # for extra methods, e.g., Hash#values_blank_to_nil

  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_paper_trail_whodunnit
  before_action :set_translation_whodunnit

  around_action :switch_locale

  # In addition to the defaul "notice" and "alert".
  #
  # I assume "notice" => "alert-info", "alert" => "alert-danger" in Bootstrap.
  # @see https://api.rubyonrails.org/classes/ActionController/Flash/ClassMethods.html#method-i-add_flash_types
  # @see https://getbootstrap.com/docs/4.0/components/alerts/
  add_flash_types :success, :warning  # Rails 4+

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
  # @example
  #   hsmain = params[:place].slice('note')
  #   @place = Place.new(**(hsmain.merge({prefecture_id: params[:place][:prefecture].to_i})))
  #   add_unsaved_trans_to_model(@place)
  #
  # @param mdl [ApplicationRecord]
  # @return [void]
  def add_unsaved_trans_to_model(mdl)
    mdl_name = mdl.class.name
    hsprm_tra, _ = split_hash_with_keys(
                 params[mdl_name.downcase],  # e.g., params["place"]
                 %w(langcode title ruby romaji alt_title alt_ruby alt_romaji))
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
  # @param alert [String, NilClass] alert message if any
  # @param warning [String, NilClass] warning message if any
  # @param notice [String, NilClass] notice message if any
  # @return [void]
  # @yield [] If given, this is called instead of simple @model.save
  def def_respond_to_format(mdl, created_updated=:created, failed: false, alert: nil, **inopts)
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
      #if !failed && (block_given? ? yield : mdl.save)
      result = (!failed && (block_given? ? yield : mdl.save))
      inopts = inopts.map{|k,v| [k, (v.respond_to?(:call) ? v.call(mdl) : v)]}.to_h
      alert = (alert.respond_to?(:call) ? alert.call(mdl) : alert)
      if result
        msg = sprintf '%s was successfully %s.', mdl.class.name, created_updated.to_s  # e.g., Article was successfully created.
        opts = { success: msg }.merge(inopts) # "success" defined in /app/controllers/application_controller.rb
        opts[:alert]  = alert if alert
        format.html { redirect_to mdl, **opts }
        format.json { render :show, status: ret_status, location: mdl }
      else
        mdl.errors.add :base, alert  # alert is included in the instance
        hsstatus = {status: :unprocessable_entity}
        format.html { render render_err,       **(hsstatus.merge inopts) } # notice (and/or warning) is, if any, passed as an option.
        format.json { render json: mdl.errors, **hsstatus }
      end
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
end

Devise::ParameterSanitizer::DEFAULT_PERMITTED_ATTRIBUTES[:sign_up] << :accept_terms
# see /vendor/bundle/ruby/*/gems/devise-*/lib/devise/parameter_sanitizer.rb

