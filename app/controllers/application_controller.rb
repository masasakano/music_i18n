class ApplicationController < ActionController::Base
  include ModuleCommon   # for split_hash_with_keys() etc
  using ModuleHashExtra  # for extra methods, e.g., Hash#values_blank_to_nil

  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_paper_trail_whodunnit
  before_action :set_translation_whodunnit

  around_action :switch_locale

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
      locale = params[:locale] || I18n.default_locale
      I18n.with_locale(locale, &action)
    end
end

Devise::ParameterSanitizer::DEFAULT_PERMITTED_ATTRIBUTES[:sign_up] << :accept_terms
# see /vendor/bundle/ruby/*/gems/devise-*/lib/devise/parameter_sanitizer.rb

