module BaseWithTranslationControllerMethods
  extend ActiveSupport::Concern

  included do
    helper_method :model_class, :model_param_key if respond_to?(:helper_method)

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

  # POST /my_models or /my_models.json
  #
  # This assumes the Controller class defines the constant `ORIG_LOCALE_TYPE_ON_CREATE`
  # which should be one of +[:disallow_nil, :allow_nil, :always_nil]+
  #
  # @result [Boolean, Object] The result of save, which is usually Boolean
  # @yield [ActiveRecord] takes ActiveRecord, and processes ActiveRecord before save after params are substituted.
  def create
    ## equivalent to, e.g., @record = @url = Url.new(model_params)
    mparams = set_record_and_authorize(__method__)
    set_orig_locale_on_create(mparams)

    yield(@record) if block_given?

    def_respond_to_format(@record, :created)    # defined in application_controller.rb
  end

    # Adjust orig_locale and Translation if necessary
    #
    # @return [Object] it depends which one is called
    def set_orig_locale_on_create(mparams = model_params)
      case self.class::ORIG_LOCALE_TYPE_ON_CREATE.to_sym
      when :disallow_nil
        create_when_nil_locale_not_allowed(mparams)
      when :allow_nil
        create_when_nil_locale_allowed(mparams)
      when :always_nil
        create_when_nil_locale_always
      else
        raise
      end
    end
    private :set_orig_locale_on_create

    # @return [ActionController::Parameters]
    def set_record_and_authorize(method=:create)
      ## equivalent to, e.g., @record = @url = Url.new(model_params)
      mparams = model_params
      @record = build_record(mparams)
      set_model_instance_variable(@record)
      authorize! method, @record
      mparams
    end
    private :set_record_and_authorize

    def create_when_nil_locale_not_allowed(mparams = model_params)
      if set_non_nil_orig_locale_from_params(@record, permitted_params: mparams)
        set_kind_from_params(@record, permitted_params: mparams)  # or mparams[:translations_attributes]
      else
        @record.errors.add(:base, "No Translation is specified.")
      end
    end
    private :create_when_nil_locale_not_allowed

    def create_when_nil_locale_allowed(mparams = model_params)
      set_orig_locale_from_params(@record, permitted_params: mparams)
      if !set_kind_from_params(@record, permitted_params: mparams)
        @record.errors.add(:base, "No Translation is specified.")
      end
    end
    private :create_when_nil_locale_allowed

    def create_when_nil_locale_always(mparams = nil)
      @record.orig_locale = nil
      @record.set_all_is_orig

      if @record.translations.blank?
        @record.errors.add(:base, "No Translation is specified.")
      end
    end
    private :create_when_nil_locale_always

  # Generic params method shared across Controllers for the BaseWithTranslation child model classes
  #
  # This can handle Controllers that contain :place_id at the top level in params.
  #
  # @example to overwrite/modify in a Controller class to include the top-level +:country_id+; e.g., PlacesController
  #    def model_params
  #      super.with_defaults(country_id: params[:country_id])
  #    end
  #     # See below to consider both the top-level and inside inclusion cases
  #
  # @return [ActionController::Parameters] permitted
  def model_params
    # filters out second (or later) Translations with a blank title
    filter_empty_secondary_translations!

    ret = params.require(model_param_key).permit(
      *permitted_main_form_keys,
      translations_attributes: Translation::PERMITTED_NESTED_ATTRIBUTES
    )

    return ret if !model_class.has_attribute?(:place_id)

    # To ensure both cases where :place_id is specified at the top level or inside +{model_name: {}}+
    extracted_place_id = params[:place_id].presence || params.dig(model_param_key, :place_id)
    ret.with_defaults(place_id: extracted_place_id)
  end

  # If orig_locale (BaseWithTranslation) is given in params, sets all is_orig (Translation), else sets orig_locale if on :create
  #
  # This is applicable to Url, Event etc where orig_locale can either be significant or nil
  # but NOT suitable for Genre, EngageHow, Sex etc, where orig_locale is always nil.
  #
  # @note {BaseWithTranslation#sync_orig_locale} (in {TranslationLifecycle}) is too crude, not considering the order.
  #
  # @example on :create
  #   @record = @url = Url.new(model_params)
  #   authorize! __method__, @record
  #   set_orig_locale_from_params(@record, permitted_params: model_params)  # defined in base_with_translation_controller_methods.rb
  #   if !set_kind_from_params(@record, permitted_params: model_params)  # defined in base_with_translation_controller_methods.rb
  #     @record.errors.add(:base, "No Translation is specified.")
  #   end
  #
  # @example on :update / this handle the case where orig_locale is directly specified by Controller
  #   set_record
  #   @record.attributes = model_params
  #   set_orig_locale_from_params(@record, permitted_params: model_params)  # defined in base_with_translation_controller_methods.rb
  #
  # @param record [BaseWithTranslation]
  # @param permitted_params: [ActionController::Parameters, Array<Hash>] mandatory. Either params[:musics] etc or its +:translations_attributes+
  # @return [void]
  def set_orig_locale_from_params(record, permitted_params: )
    return set_all_is_orig_from_orig_locale(record, permitted_params) if permitted_params.has_key?(:orig_locale)
    return if !record.new_record?

    arhs = translations_attributes_array(permitted_params)
    return if arhs.empty?

    if !arhs[0].has_key?(:is_orig)
      return  # record.orig_locale should be always nil (like Genre)
    elsif arhs[0][:is_orig]
      record.orig_locale = arhs[0][:langcode]&.strip
    else
      record.orig_locale = nil
    end
  end

  # Updates {Translation#is_orig} of all associated based on {BaseWithTranslation#orig_locale}
  #
  # @param record [BaseWithTranslation]
  # @return [NilClass, String] orig_locale
  def set_all_is_orig_from_orig_locale(record, permitted_params)
    record.set_all_is_orig
    return if record.orig_locale.blank?

    ## Now, checking if this is called on :create, where
    #  (up to) two Translation-s with the same langcode
    #  with nil weight (as usual on :create, though never otherwise)
    #  are given AND if the second one gets is_orig=true; if so,
    #  the first one should get is_orig=true.
    arhs = translations_attributes_array(permitted_params)
    return if arhs.size <= 1

    if arhs[1][:is_orig] && arhs[0][:langcode] == arhs[1][:langcode] && !arhs[0][:weight]
      tra1 = record.translations.find(&:is_orig)
      tra0 = record.translations.find{ |t| !t.is_orig && t.langcode == record.orig_locale }
      if tra0 && tra1  # Should be always the case, but playing safe...
        tra0.is_orig = true
        tra1.is_orig = false
      end
    end
  end

  # Set orig_locale (BaseWithTranslation) and is_orig (Translation) when orig_locale=nil is not allowed.
  #
  # This is applicable to Artist, Music, HaramiVid, Place, where orig_locale is never nil
  # (except unknown), but not Event, Genre, EngageHow, Sex etc, where orig_locale is nil either always or sometimes.
  #
  # @note If orig_local=nil is allowed, call {BaseWithTranslation#sync_orig_locale} defined in {TranslationLifecycle}
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

    def model_class
      @model_class ||= controller_name.classify.constantize
    end

    # Defaults to :url, :music, etc. Can be overridden in a controller if needed.
    #
    # @return [Symbol] the singular symbol/string parameter key (e.g. "url", "music")
    def model_param_key
      ## Equivalent to: controller_name.singularize.to_sym
      @model_param_key ||= model_class.model_name.param_key
    end

    # Assigns @record to @url, @music, etc. so existing views/forms continue to work
    def set_model_instance_variable(record)
      instance_variable_set("@#{model_param_key}", record)
    end

    # Extracted hook: allows specific controllers to customize record instantiation
    def build_record(attributes = {})
      model_class.new(attributes)
    end

    # @return [BaseWithTranslation, NilClass] @record if set here, or nil if @record has been already set and not reset here.
    def set_record
      if @record
        nil
      else
        @record = model_class.find(params[:id])
        set_model_instance_variable(@record)
        @record
      end
    end    # Infers the model class (e.g. UrlsController -> Url, MusicsController -> Music)

    # Reads MAIN_FORM_KEYS from the host controller at runtime
    #
    # @return [Array<Symbol>]
    def permitted_main_form_keys
      if self.class.const_defined?(:MAIN_FORM_KEYS)
        (self.class::MAIN_FORM_KEYS.map(&:to_sym) + [:orig_locale]).uniq
      else
        [:orig_locale]
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

    def filter_empty_secondary_translations!
      trans_attrs = params.dig(model_param_key, :translations_attributes)
      return if trans_attrs.blank?

      if trans_attrs.is_a?(ActionController::Parameters) || trans_attrs.respond_to?(:each_pair) # Hash-like
        # HTML forms send a hash/parameters with String keys like "0", "1"
        sorted_keys = trans_attrs.keys.sort_by(&:to_s)

        # Skips the first slot (sorted_keys[0]); inspect index 1 and beyond
        sorted_keys[1..]&.each do |key|
          entry = trans_attrs[key]

          # Deletes from params/Hash if a new record slot (no :id) and title is blank
          # and NOT marked for deletion via _destroy
          if entry[:title].blank? && entry[:id].blank? && entry[:_destroy].blank?
            trans_attrs.delete(key)
          end
        end

      elsif trans_attrs.is_a?(Array)
        # Controller tests or APIs might pass an Array of Hashes
        first = trans_attrs[0]
        rest = (trans_attrs[1..] || []).reject do |entry|
          entry[:title].blank? && entry[:id].blank? && entry[:_destroy].blank?
        end

        # Reconstructs the params parameter
        params[model_param_key][:translations_attributes] = [first, *rest].compact
      end
    end
end
