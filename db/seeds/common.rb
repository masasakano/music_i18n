# coding: utf-8

# read as follows (providing this is read from Ruby files for seeding):
#   require(File.basename(__FILE__)+"/seeds_common.rb")
#
module Seeds
  module Common
  
    include ModuleCommon  # for seed_fname2print etc

    # Everything is a function
    module_function
  
    # Default translation weight
    DEF_TRANSLATION_WEIGHT = 90
  
    # Save a model
    #
    # For the first run, a model (seed) is saved.
    # If the model is NOT {ActiveRecord#new_record?}, parameters are updated only if
    # the value is blank and a seed values is defined.
    #
    # Returns 1 if created/updated, else 0.
    #
    # The given seed hash is like this:
    #
    #    singer: {
    #      ja: "歌手",
    #      en: ["Singer", "Vocalist"]  # title, alt_title
    #      orig_langcode: nil,
    #      mname: unknown,
    #      weight: 999,
    #      note: nil,
    #      regex: /^(歌手|singer)/i,  # to check potential duplicates based on Translations (c.f., seeds_event_group.rb), but is irrelevant to this method; basically, this may be used to determine `model` by the caller before calling this method.
    #    }
    #
    # @param model [ActiveRecord]
    # @param seed1 [Hash] A single Seed hash (see above)
    # @param attrs: [Array<Symbol, String>] Attributes to setup (or update if blank); e.g., %i(weight note)
    # @return [Integer] 1 if updated, else 0.
    def model_save(model, seed1, attrs: [])
      # To play safe; this routine should not be called if model is not a new record.
      changed = model.new_record?  # true if the model itself is new (let alone Translation)
  
      attrs.each do |ek|
        # If it already exists, processing is skipped basically, except blank attributes may be updated.
        next if !model.new_record? && (seed1[ek].blank? || model.send(ek).present?)
        changed = 1 if !model.new_record?  # (at least partly) modified, hence +1 in increment is guaranteed.
        model.send(ek.to_s+"=", seed1[ek])
      end
  
      begin
        model.save!  # EngageEventItemHow saved.  This should not raise an Exception, for Countries should have been already defined!
      rescue ActiveRecord::RecordInvalid
        msg = "ERROR(#{__FILE__}:#{__method__}): EngageEventItemHow#save! failed while attempting to save ja=(#{seed1[:ja]}).  This should never happen, except after a direct Database manipulation (such as DB migration rollback) has left some orphan Translations WITHOUT a parent; check out the log file for a WARNING message."
        warn msg
        Rails.logger.error msg
        raise
      end
  
      (changed ? 1 : 0)  # +1 if the model itself is new (let alone Translation)
    end  # def model_save()
  
    # Save seeded Translations
    #
    # If a Translation for the langcode of a seed exists, it is never updated with the seed.
    #
    # @param model [ActiveRecord]
    # @param seed1 [Hash] A single Seed hash (see above)
    # @return [Integer] Number of updated Translations.
    def translation_save(model, seed1)
      klass = model.class
      n_changed = 0
  
      # original langcode for seeded Translations.
      # A significant langcode is used ONLY IF there is no conflict with the existing Translations.
      orig_langcode = (seed1[:orig_langcode] && !model.reload.orig_langcode && seed1[:orig_langcode])  # Either nil or "en" etc. seed1[..] repeated for the sake of processing efficiency
  
      ## Create Translations if not yet
      tras = model.best_translations
      %i(en ja fr).each do |lcode|
        next if !seed1.key?(lcode)
        next if tras.key?(lcode)  # Translation of the language for EngageEventItemHow already defined?. If so, skip.
  
        is_orig = (orig_langcode ? (orig_langcode.to_s ==  lcode.to_s) : nil)
        weight = ((klass.const_defined?(:UNKNOWN_TITLES) && seed1[lcode] == klass::UNKNOWN_TITLES[lcode.to_s]) ? 0 : DEF_TRANSLATION_WEIGHT) # Translations for the uncategorized/unknown have weight=0 (i.e., will be never modified).
        hstit = %i(title alt_title).zip([seed1[lcode]].flatten.map{|i| i.strip}).to_h
        model.with_translation(langcode: lcode.to_s, is_orig: is_orig, weight: weight, **hstit)
        n_changed += 1   # +1 because of Translation creation
      end # %i(en ja fr).each do |lcode|
  
      n_changed
    end

    # Core routine for load_seeds
    #
    # All seeded records for the class are created, if not yet created.  At the same time,
    # this sets hash +self::MODELS+ with a key of +self::SEED_DATA+ for the model (regardless of new or existing).
    #
    # In default, the Hash of +SEEDS[][:regex]+ is used to identify the existing record;
    # it is either Regexp or Proc. Alternatively, a block can be given to implement
    # an algorithm by the caller.
    #
    # @example
    #    _load_seeds_core(EngagePlayHow, %i(weight note))
    #    _load_seeds_core(AbcDef, %i(mname weight note)){|ea_hs, key| AbcDef.find_or_initialize(...)}
    #
    # @param attrs [Array<Symbol>] Array of attributes for the main model to load.
    # @param klass: [Class, NilClass] (Optional) Model class. If not specified, constant RECORD_CLASS is tried and then it is guessed from the Module name.
    # @return [Integer] Number of created/updated entries
    # @yield [Hash, Symbol] (Optional) Hash (==SEEDS[:key]) followed by the :key, is given.  Can be ignored.
    # @yieldreturn [ApplicationRecord] The matching (or new) model or nil
    def _load_seeds_core(attrs, klass: nil)
      klass ||= ((k=:RECORD_CLASS; self.const_defined?(k) && self.const_get(k)) || self.name.split("::")[-1].constantize)  # ActiveRecord (ApplicationRecord)
      n_changed = 0

      self::SEED_DATA.each_pair do |key, ehs|
        model =
          if block_given?
            yield(ehs, key)
          elsif ehs[:regex].respond_to?(:call)
            ehs[:regex].call(ehs, key)
          else
            klass.find_by_regex(:titles, ehs[:regex])
          end

        model ||= klass.new

        if model.new_record?
          n_changed += model_save(model, ehs, attrs: attrs)
          model.reload
        end
        self::MODELS[key] =  model

        n_changed += translation_save(model, ehs)
      end

      n_changed
    end # def _load_seeds_core(attrs, klass: nil)
    private :_load_seeds_core
  end # moduleCommon
end # module Seeds
