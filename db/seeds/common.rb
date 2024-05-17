# coding: utf-8

# read as either of the following (providing this is read from Ruby files in this directory for seeding):
#   require(File.basename(__FILE__)+"/common.rb")
#   require_relative "common.rb"
#
module Seeds
  module Common
  
    include ModuleCommon  # for seed_fname2print etc

    # Everything is a function
    module_function

    # Default translation weight
    DEF_TRANSLATION_WEIGHT = 90

    # syadmin pID (so it will be set dynamically)
    USER_IDS = {
      sysadmin: nil
    }

    # Returns a YAML-safe title (or alt_title)
    #
    # When a String is very long, it may cause an Error. This routine circumvents it.
    #
    # @note
    #   I am not sure this is 100% YAML safe.  +String#to_yaml+ does not work in this case.
    #
    # @example
    #   yaml_title(my_data[langcode], :alt_title)
    #   yaml_title(nil)                 #=> ""
    #   yaml_title("Abcd")              #=> "Abcd"
    #   yaml_title("Abcd", :alt_title)  #=> ""
    #   yaml_title(["A", "XY"], :alt_title)  #=> "XY"
    #
    # @param data [String, Array<String>, NilClass] like +SEED_DATA[:ja]+ i.e., either String or 2-element Array of String as in 
    # @param title [Symbol] :title or :alt_title
    # @return [String]
    def yaml_title(data, title=:title)
      index = ((:title == title) ? 0 : 1)
      (s=[data].flatten[index]).present? ? s.gsub(/\n/, "  ").inspect : ""
    end

  
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
    #      user_create_id: :special_sysadmin_id,  # special meaniing
    #      user_update_id: Proc.new{|ehs, key| ehs[:user_create_id]+1 if :singer == key.to_sym },  # silly example
    #      note: nil,
    #      regex: /^(歌手|singer)/i,  # to check potential duplicates based on Translations (c.f., seeds_event_group.rb), but is irrelevant to this method; basically, this may be used to determine `model` by the caller before calling this method.
    #    }
    #
    # @param model [ActiveRecord]
    # @param seed1 [Hash] A single Seed hash (see above)
    # @param attrs: [Array<Symbol, String>] Attributes to setup (or update if blank); e.g., %i(weight note)
    # @return [Integer] 1 if updated, else 0.
    def model_save(model, seed1, attrs: [])
      USER_IDS[:sysadmin] ||= ((sysadmin=(User.roots.first rescue nil)) ? sysadmin.id : nil)  # rescue is to play safe in case RoleCategory.root_category returns nil.

      # To play safe; this routine should not be called if model is not a new record.
      changed = model.new_record?  # true if the model itself is new (let alone Translation)
  
      attrs.each do |ek|
        # If it already exists, processing is skipped basically, except blank attributes may be updated.
        next if !model.new_record? && (seed1[ek].blank? || model.send(ek).present?)

        changed = 1 if !model.new_record?  # (at least partly) modified, hence +1 in increment is guaranteed.
        metho_w = ek.to_s+"="
        if !model.respond_to?(metho_w)
          raise "ERROR(NoMethodError): (File=#{File.basename __FILE__}):(#{self.name}.#{__method__}) method(#{metho_w.to_sym.inspect}) specified in the argument #{attrs.inspect} is not defined for model #{model.inspect}  The caller maybe gives the wrong argument. Contact the code developer."
        end
        val =
          if "_id" == ek.to_s[-3..-1] && :special_sysadmin_id == seed1[ek]
            USER_IDS[:sysadmin] 
          elsif seed1[ek].respond_to? :call
            seed1[ek].call(seed1, ek)  # passing the current SEED Hash and the main key for the Hash
          else
            seed1[ek]
          end
        model.send(metho_w, val)
      end
  
      do_validate = true
      if !model.valid?
        hserr = model.errors.to_hash
        errkey = hserr.keys.first
        if 1 == hserr.keys.size &&
           [:base, :title].include?(errkey) &&
           1 == hserr[errkey].size &&
           "no translations are defined" == hserr[errkey].first  # Defined in /models/base_with_translation.rb
          # Basically, if only the validation error is "no translations are defined",
          # we skip the validation and save Translations in the next step.
          do_validate = false
        end
      end

      begin
        model.save!(validate: do_validate)  # Model saved.  This should not raise an Exception, for Countries should have been already defined!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey
        klass_name = (self.const_defined?(:RECORD_CLASS) ? self::RECORD_CLASS.name : "Model")
        msg = "ERROR(#{__FILE__}:#{__method__}): #{klass_name}#save! failed while attempting to save model=#{model.inspect} for Seed of ja=(#{seed1[:ja]}).  This should never happen, except after a direct Database manipulation (such as DB migration rollback) has left some orphan Translations WITHOUT a parent; check out the log file for a WARNING message."
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
        next if tras.key?(lcode)  # Translation of the language for PlayRole already defined?. If so, skip.
  
        is_orig = (orig_langcode ? (orig_langcode.to_s ==  lcode.to_s) : nil)
        weight = ((klass.const_defined?(:UNKNOWN_TITLES) && seed1[lcode] == klass::UNKNOWN_TITLES[lcode.to_s]) ? 0 : DEF_TRANSLATION_WEIGHT) # Translations for the uncategorized/unknown have weight=0 (i.e., will be never modified).
        hstit = %i(title alt_title).zip([seed1[lcode]].flatten.map{|i| i.strip}).to_h
        begin
          model.with_translation(langcode: lcode.to_s, is_orig: is_orig, weight: weight, **hstit)
        rescue ActiveRecord::RecordInvalid
          if "ModelSummary" == klass.name
            warn "ERROR: Possibly there is an 'orphan' ModelSummary. Check it out with UI at /model_summaries/ as sysadmin."
          end
          raise
        end
        n_changed += 1   # +1 because of Translation creation
      end # %i(en ja fr).each do |lcode|
  
      n_changed
    end

    # Core routine for load_seeds, which should be defined in each class that includes this Module
    #
    # All seeded records for the class are created, if not yet created.  At the same time,
    # this sets hash +self::MODELS+ with a key of +self::SEED_DATA+ for the model (regardless of new or existing).
    #
    # In default, the Hash of +SEEDS[][:regex]+ is used to identify the existing record;
    # it is either Regexp or Proc (see @yield for the parameters). Alternatively, a block can be given to implement
    # an algorithm by the caller.  Or, if +find_by+ option is given, the specified
    # attribute is used to find the existing one (n.b., the given block has a higher priority).
    #
    # In none of the above is provided, the exact title in a standard language is used to find one (duplications are not checked).
    #
    # @example
    #    _load_seeds_core(%i(weight note))  # ActiveRecord Class is derived from RECORD_CLASS.
    #    _load_seeds_core(%i(mname weight note), klass: AbcDef){|ea_hs, key| AbcDef.find_or_initialize(...)}
    #
    # @param attrs [Array<Symbol>] Array of attributes for the main model to load.
    # @param klass: [Class, NilClass] (Optional) Model class. If not specified, constant RECORD_CLASS is tried and then it is guessed from the Module name.
    # @param find_by: [Symbol, String] (Optional) If given, this attribute is used to find the existing corresponding record.
    # @return [Integer] Number of created/updated entries
    # @yield [Hash, Symbol] (Optional) Hash (==SEEDS[:key]) followed by the :key, is given.  Can be ignored.
    # @yieldreturn [ApplicationRecord] The matching (or new) model or nil
    def _load_seeds_core(attrs, klass: nil, find_by: nil)
      self::MODELS ||= {}  # The caller may want to define it before calling this.
      klass ||= ((k=:RECORD_CLASS; self.const_defined?(k) && self.const_get(k)) || self.name.split("::")[-1].constantize)  # ActiveRecord Class (ApplicationRecord)
      n_changed = 0
      self::SEED_DATA.each_pair do |key, ehs|
        model =
          if block_given?
            yield(ehs, key)
          elsif find_by
            klass.find_by(**({find_by.to_sym => ehs[find_by]}))
          elsif ehs[:regex].respond_to?(:call)
            ehs[:regex].call(ehs, key)  # passing the current SEED Hash and the main key for the Hash
          elsif ehs[:regex]
            klass.find_by_regex(:titles, ehs[:regex])
          else  # If :regex is not found in self::SEED_DATA, the exact :title (but not :alt_title) is used to identify the existing record.
            _find_bwt_from_exact_translations(ehs, klass: nil)
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

    # @param find_by: [Symbol, String] (Optional) If given, this attribute is used to find the existing corresponding record.
    # @return [Integer] Number of created/updated entries
    # @yield [Hash, Symbol] (Optional) Hash (==SEEDS[:key]) followed by the :key, is given.  Can be ignored.
    # @yieldreturn [ApplicationRecord] The matching (or new) model or nil
    def _find_bwt_from_exact_translations(seed_hs, klass: nil)
      klass ||= ((k=:RECORD_CLASS; self.const_defined?(k) && self.const_get(k)) || self.name.split("::")[-1].constantize)  # ActiveRecord Class (ApplicationRecord)
            artrans = %w(ja en fr kr cn de es).map{|lc| seed_hs[lc] && {langcode: lc, title: seed_hs[lc]}.with_indifferent_access}.compact
            cand = klass.find_all_by_exact_translations(artrans).first  # defined in BaseWithTranslation
            if cand
              arwrong = klass.find_all_inconsistent_translations(artrans).compact
              if !arwrong.empty?
                arlcs = arwrong.map{|i| i[:langcode].to_s}
                msg = "WARNING: One or more Translations #{arlcs.inspect} for a seed have apparently changed from the defaults! Check out #{klass.name}.find(#{cand.id}) :\n Expected[langcode, title]=#{artrans.map{|i| i.values.flatten}.inspect}\n  Reality[langcode, title]=#{cand.translations.pluck(:langcode, :title)}"
                Rails.logger.warn msg
                warn msg
              end
            end
            cand
    end
  end # moduleCommon
end # module Seeds
