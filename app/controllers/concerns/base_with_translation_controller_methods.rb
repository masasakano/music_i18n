module BaseWithTranslationControllerMethods
  extend ActiveSupport::Concern

  # Set orig_locale (BaseWithTranslation) and is_orig (Translation) when orig_locale=nil is not allowed.
  #
  # This is applicable to Artist, Music, HaramiVid, Place, where orig_locale is never nil
  # (except unknown), but not Event, Genre, EngageHow, Sex etc, where orig_locale is nil either always or sometimes.
  #
  # @note If orig_local=nil is allowed, call {BaseWithTranslation#sync_orig_locale}
  #
  # @example on :create
  #   @record = @music = Music.new(music_params)
  #   authorize! __method__, @music
  #   set_non_nil_orig_locale_from_params(@music, permitted_params: music_params)  # defined in base_with_translation_controller_methods.rb
  #   set_kind_from_params(@music, permitted_params: music_params)  # defined in base_with_translation_controller_methods.rb
  #
  # @param record [BaseWithTranslation]
  # @param permitted_params: [Array<Hash>] mandatory. Either params[:musics] etc or its +:translations_attributes+
  def set_non_nil_orig_locale_from_params(record, permitted_params: )
    tra_params = translations_attributes_array(permitted_params)
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
  end

  # Adjust :kind
  #
  # First one in each langcode in the Translation parameter group is given kind="full"
  # unless one of them in the langcode already has kind="full".
  # Everything else is given "alt" unless already set.
  #
  # @example on :create
  #   @record = @music = Music.new(music_params)
  #   authorize! __method__, @music
  #   set_non_nil_orig_locale_from_params(@music, permitted_params: music_params)  # defined in base_with_translation_controller_methods.rb
  #   set_kind_from_params(@music, permitted_params: music_params)  # defined in base_with_translation_controller_methods.rb
  #
  # @param record [BaseWithTranslation]
  # @param permitted_params: [Array<Hash>] mandatory. Either params[:musics] etc or its +:translations_attributes+
  def set_kind_from_params(record, permitted_params: )
    tra_params = translations_attributes_array(permitted_params)
    hs_pri_tras = tra_params.map{ _1[:langcode] }.uniq.map { |locale|
      [locale, tra_params.find { _1[:langcode] == locale }[:title]]
    }.to_h.with_indifferent_access

    record.assign_auto_kinds(hs_pri_tras)
  end

  private

  def translation_attributes
    Translation::PERMITTED_NESTED_ATTRIBUTES
  end

  # Converts translations_attributes (whether Hash, Array, or nil) into a clean Array
  #
  # @param permitted_params [ActionController::Parameters]
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
