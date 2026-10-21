module BaseWithTranslationControllerMethods
  extend ActiveSupport::Concern

  included do
    # 1. Derives the parameter name (e.g., UrlsController -> "url", MusicsController -> "music")
    param_key = controller_name.singularize
    alias_method_name = "#{param_key}_params"

    # 2. Dynamically defines <model>_params (e.g., url_params) delegating to model_params
    #    This is better than aliasing because this method still refers to model_params
    #    even if Controller that includes this module modifies model_params
    unless method_defined?(alias_method_name)
      define_method(alias_method_name) do
        model_params
      end
    end
  end

  # Generic params method shared across Controllers for the BaseWithTranslation child model classes
  def model_params
    params.require(model_param_key).permit(
      *permitted_main_form_keys,
      translations_attributes: Translation::PERMITTED_NESTED_ATTRIBUTES
    )
  end

  # Set orig_locale (BaseWithTranslation) and is_orig (Translation) when orig_locale=nil is not allowed.
  #
  # This is applicable to Artist, Music, HaramiVid, Place, where orig_locale is never nil
  # (except unknown), but not Event, Genre, EngageHow, Sex etc, where orig_locale is nil either always or sometimes.
  #
  # @note If orig_local=nil is allowed, call {BaseWithTranslation#sync_orig_locale}
  #
  # @example on :create
  #   @record = @music = Music.new(music_params)
  #   authorize! __method__, @record
  #   if set_non_nil_orig_locale_from_params(@record, permitted_params: music_params)  # defined in base_with_translation_controller_methods.rb
  #     set_kind_from_params(@record, permitted_params: music_params)  # defined in base_with_translation_controller_methods.rb
  #   else
  #     @record.errors.add(:base, "No Translation is specified.")
  #   end
  #
  # @param record [BaseWithTranslation]
  # @param permitted_params: [ActionController::Parameters, Array<Hash>] mandatory. Either params[:musics] etc or its +:translations_attributes+
  # @return [NilClass, TrueClass] nil if Translation is NOT found. Otherwise true (normal ends)
  def set_non_nil_orig_locale_from_params(record, permitted_params: )
    tra_params = translations_attributes_array(permitted_params)  # guaranteed Array
    return if tra_params.empty? || !tra_params.first.respond_to?(:[])  # nil?

    if record.orig_locale.blank?
      record.orig_locale = tra_params.first[:langcode]
    end

    # set is_orig all Translations false except for the first one of orig_locale.
    has_true = false
    record.translations.each do |etra|
      if etra.langcode == record.orig_locale && !has_true
        has_true = true
        etra.is_orig = true
      else
        etra.is_orig = false
      end
    end
    true
  end

  # Adjust :kind
  #
  # First one in each langcode in the Translation parameter group is given kind="full"
  # unless one of them in the langcode already has kind="full".
  # Everything else is given "alt" unless already set.
  #
  # Example: See {#set_non_nil_orig_locale_from_params} if orig_locale is expected to be non-nil.
  #
  # @example on :create where orig_locale is expected to be nil (e.g., {Genre}).
  #   @record = @genre = Genre.new(model_params)
  #   authorize! __method__, @record
  #   if !set_kind_from_params(@record, permitted_params: model_params)  # defined in base_with_translation_controller_methods.rb
  #     @record.errors.add(:base, "No Translation is specified.")
  #   end
  #
  # @param record [BaseWithTranslation]
  # @param permitted_params: [ActionController::Parameters, Array<Hash>] mandatory. Either params[:musics] etc or its +:translations_attributes+
  # @return [NilClass, TrueClass] nil if Translation is NOT found. Otherwise true (normal ends)
  def set_kind_from_params(record, permitted_params: )
    tra_params = translations_attributes_array(permitted_params)
    return if tra_params.empty? || !tra_params.first.respond_to?(:[])  # nil?

    hs_pri_tras = tra_params.map{ _1[:langcode] }.uniq.map { |locale|
      [locale, tra_params.find { _1[:langcode] == locale }[:title]]
    }.to_h.with_indifferent_access

    record.assign_auto_kinds(hs_pri_tras)
    true
  end

  private

  # Defaults to :url, :music, etc. Can be overridden in a controller if needed.
  #
  # @return [Symbol]
  def model_param_key
    controller_name.singularize.to_sym
  end

  # Reads MAIN_FORM_KEYS from the host controller at runtime
  #
  # @return [Array<Symbol>]
  def permitted_main_form_keys
    if self.class.const_defined?(:MAIN_FORM_KEYS)
      self.class::MAIN_FORM_KEYS.map(&:to_sym)
    else
      []
    end
  end

  def translation_attributes
    Translation::PERMITTED_NESTED_ATTRIBUTES
  end

  # Converts translations_attributes (whether Hash, Array, or nil) into a clean Array
  #
  # @example
  #   array_of_translation_like_hashes = translations_attributes_array(music_params)
  #
  # @param permitted_params [ActionController::Parameters, Hash, Array]
  # @return [Array]
  def translations_attributes_array(permitted_params)
    tra_params =
      if permitted_params.respond_to?(:has_key?)
        permitted_params[:translations_attributes] 
      else
        permitted_params
      end

    if tra_params.respond_to?(:values)
      tra_params.values
    else
      Array.wrap(tra_params)
    end
  end
end
