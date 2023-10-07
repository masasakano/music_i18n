
# Superclass of Musics::MergesController etc
#
# {CheckedDisabled} defined in +/lib/checked_disabled.rb+ is a key helper class.
#
# Child classes are so far {Musics::MergesController} and {Artists::MergesController} .
class BaseMergesController < ApplicationController
  # Symbol-Key to the actual Form parameter key
  #
  # In each subclass, make sure to define
  #   MODEL_SYM = :music  # if for Music::MergesController class
  #   FORM_MERGE_KEYS     # Array of used keys in the form of the class like :other_music_id (or :other_artist_id)
  FORM_MERGE = {
    other_music_id:     'other_music',
    other_music_title:  'other_music_title',
    other_artist_id:    'other_artist',
    other_artist_title: 'other_artist_title',
    to_index: 'to_index',
    lang_orig: 'lang_orig',
    lang_trans: 'lang_trans',
    engage: 'engage',
    prefecture_place: 'prefecture_place',
    genre: 'genre',  # Music only
    year: 'year',    # Music only
    sex: 'sex',           # Artist only
    birthday: 'birthday', # Artist only
    wiki_en: 'wiki_en',   # Artist only
    wiki_ja: 'wiki_ja',   # Artist only
    note: 'note',
  }.with_indifferent_access

  ## This constant should be defined in the sub-class to indicate the mandatory parameter name for +params+
  # MODEL_SYM = :music  # an Example

  private

    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def _translations_htmls(models)
      contents = models.map do |em, i|
        # exist_editable = em.translations.where.not(id: em.orig_translation.id).any?{|et| can?(:ud, et)}
        ### I have decided not to check ability... too complicated!
        arstr = []
        em.translations.where(is_orig: false).or(em.translations.where(is_orig: nil)).sort{|a, b|
          # Sorted in the order of Language (langcode/locale) and weight
          w = ((I18n.available_locales.find_index(a.langcode.to_sym) || Float::INFINITY) <=>
               (I18n.available_locales.find_index(b.langcode.to_sym) || Float::INFINITY))
          next w if w != 0
          (a.weight || Float::INFINITY) <=> (b.weight || Float::INFINITY)
        }.each do |et|
          # next if et.langcode == orig_trans.langcode
          arstr << ERB::Util.html_escape(sprintf("[%s] %s / %s", et.langcode, et.title, et.alt_title))
        end
        arstr.join("&nbsp;&nbsp;<br>").html_safe
      end
    end

  private

    # Only allow a list of trusted parameters through.
    #
    # @param fallback [Class, BaseWithTranslation, String, Symbol] like +:music+
    def merge_params(fallback: model=nil)
      prm = (self.class.const_defined?(:MODEL_SYM) && self.class::MODEL_SYM ||  # e.g., :music
             model.respond_to?(:name) && model.name.underscore ||
             model.respond_to?(:downcase) && model.downcase ||
             model.respond_to?(:to_sym) && model.to_sym )
      params.require(prm).permit(*FORM_MERGE.keys)
    end

    # returns 0 or 1 for the given key for params
    #
    # If the parameter is nil (which happens when the user has no priviledge over
    # Translations), the default value is that of +:to_index+
    #
    # Note that +merge_params[:to_index].to_i+ returns 0 when either
    # (1) it is indeed 0,
    # (2) it is nil;
    # hence it is necessary to evaluate +merge_params[:to_index]+ as this method does.
    #
    # @param key [Symbol] Parameters for params. See the constant {FORM_MERGE}.
    # @param fallback [Class, BaseWithTranslation, String, Symbol] of the original {BaseWithTranslation} like +:music+
    def merge_param_int(key, fallback: model=nil)
      ((ret = merge_params[key]).blank? ? merge_params[FORM_MERGE[:to_index]] : ret).to_i
    end

    # Finds and returns the other {BaseWithTranslation} model (to merge)
    #
    # For {Music}, for example, the ID is taken from +params[:other_music_id]+
    # or +params[:music][:other_music_id]+
    #
    # @example
    #   @musics = []
    #   @musics << Music.find(params[:id])
    #   begin
    #     @musics << get_other_model(@musics[0])  # defined in base_merges_controller.rb
    #   rescue ActiveRecord::RecordNotFound
    #   end
    #
    # @return [BaseWithTranslation] the reference instance
    # @raise [ActionController::ParameterMissing] if neither exists (which should never happen through UI).
    # @raise [ActiveRecord::RecordNotFound] if +:other_{model}_id+ is not given and no +Model+ matches +:other_{model}_title+
    def get_other_model(model)
      mo_class = model.class
      mo_name = mo_class.name.underscore
      key_i = "other_"+mo_name+"_id"
      other_id   = params.has_key?(key_i) && params.permit(key_i)[key_i] || nil
      other_id ||= params.require(mo_name).permit(key_i)[key_i]  # it should never be nil, if through UI
      logger.info "(#{File.basename __FILE__}:#{__method__}): #{key_i.to_sym.inspect} is missing in params. Now searching for its 'title' counterpart" if Rails.env.development? && !other_id
      other_id = (params.permit(key_i)[key_i] || params.require(mo_name).permit(key_i)[key_i])
      return mo_class.find(other_id) if !other_id.blank?

      key_t = "other_"+mo_name+"_title"
      mo_title = params.require(mo_name).permit(key_t)[key_t]
      if !mo_title || mo_title.strip.blank?  # raises ActiveRecord::RecordNotFound
        logger.error "(#{File.basename __FILE__}:#{__method__}): Neither #{key_i.to_sym.inspect} nor #{key_t.to_sym.inspect} is found, which should never happen through UI: params=#{params}"
        return mo_class.find(nil) if !mo_title || mo_title.strip.blank?  # raises ActiveRecord::RecordNotFound
      end

      search_str, lcode, model_id = prepare_autocomplete_model(mo_title)
      return mo_class.find(model_id) if model_id

      armodel = model.select_translations_partial_str_except_self(
        :titles, search_str, langcode: lcode
      ).map{|i| i.translatable}.uniq

      if armodel.empty?  # raises ActiveRecord::RecordNotFound
        logger.error "ERROR(#{__method__}): Neither #{key_i.to_sym.inspect} nor the matching content for #{key_t.to_sym.inspect} is found, which should never happen through UI: params=#{params}"
        return mo_class.find(nil)  # raises ActiveRecord::RecordNotFound
      end

      if armodel.size > 1
        if flash[:warning]
          flash[:warning] << "  " 
        else
          flash[:warning] = ""
        end
        flash[:warning] << sprintf("Found more than 1 %s for word=(%s).", mo_class.name, mo_title.strip)
      end
      armodel.first
    end


    # Returns the merged model based on the given two models
    #
    # For {Music}, for example, the ID is taken from +params[:other_music_id]+
    # or +params[:music][:other_music_id]+
    #
    # @example
    #   @musics = []
    #   @musics << Music.find(params[:id])
    #   begin
    #     @musics << get_other_model(@musics[0])  # defined in base_merges_controller.rb
    #   rescue ActiveRecord::RecordNotFound
    #   end
    #
    # @param [Array<BaseWithTranslation>] two-element Array.
    # @return [BaseWithTranslation] the reference instance
    # @raise [ActionController::ParameterMissing] if neither exists (which should never happen through UI).
    # @raise [ActiveRecord::RecordNotFound] if +:other_{model}_id+ is not given and no +Model+ matches +:other_{model}_title+
    def get_merged_model(models, to_id: nil)
      to_id ||= models[0].id
      merged = models[0].class.new(models[0].attributes)
      merged.id = to_id
      merged.instance_variable_set(:@id_backup, to_id)
      merged.define_singleton_method(:id_backup){@id_backup}
      merged.unsaved_translations = models[0].translations
      merged.note = [models[0].note, models[1].note].compact.join(" ").strip
      merged.note = nil if merged.note.blank?
      merged
    end


    # Returns Hash of {CheckedDisabled} with keys included in constant +FORM_MERGE_KEYS+
    # defined in each subclass.
    #
    # Note that when {CheckedDisabled#disabled?} is false, one or both of the elements
    # can be nil and the View will display nothing for them, as opposed to a radiob button
    # with spaces (which I don't think would be a valid HTML). {CheckedDisabled#disabled?} of true
    # means any of the HTML +input+ tags for the element (or row) is disabled, if there is any.
    #
    # @param model [Array<ActiveRecord>]
    # @return [Hash<CheckedDisabled>] e.g., +{lang_trans: CheckedDisabled.new(contents: _to_print_on_form, ...}+
    def all_checked_disabled(models)
      chkmodels = models[0..1]
      self.class::FORM_MERGE_KEYS.map{ |ea_fmk|
        [ea_fmk, 
           case ea_fmk
           when :to_index, :lang_orig
             CheckedDisabled.new(checked_index: 0, disabled: false)
           when :lang_trans
             _non_orig_translations_checked_disabled(chkmodels)
           when :engage
             torfs = chkmodels.map{|em| em.engages.exists? ? true : nil }
             CheckedDisabled.new(checked_index: torfs.find_index{|tf| tf}, disabled: (1 == torfs.compact.size))
           when :prefecture_place
             CheckedDisabled.new(chkmodels, :place)
           when :genre, :year, :sex, :wiki_en, :wiki_ja
             CheckedDisabled.new(chkmodels, ea_fmk)
           when :birthday
             CheckedDisabled.new(chkmodels, :any_birthdate_defined?)
           when :note
             next  # ignoredd!
           when :other_music_id, :other_music_title, :other_artist_id, :other_artist_title
             next  # ignoredd!
           else
             logger.warning "Unexpected key (#{ea_fmk}). Contact the code developer."
             #next
             raise
           end
        ]
      }.compact.to_h
    end

    # Preparation routine.
    #
    # In +update+ (not +edit+), a string query for the model's Translation
    # candidate is passed. So, we need to retrieve the model based on it.
    # In principle, there may be no models or multiple models.
    # Autocomplete helps to identify it uniqlely by appending the locale (langcode)
    # and ID at the end of the query string, although users can editi them technically
    # if they insist. Now the Controller for update must identify the model
    # sending a query to DB. This method does preparation for it.
    #
    # Specifically, a search string after autocomplete may be like
    #   "Queen [en] [123]"
    # which includes the language and its {BaseWithTranslation} model ID.
    # This method separates them to enable a subsequent DB query.
    #
    # @return [Array<String, String, Integer>] e.g., ["Queen", "en", 123] (Search-String, Locale, ID)
    def prepare_autocomplete_model(str)
      re_locales = I18n.available_locales.map(&:to_s).join("|")
      lcode = nil
      model_id = nil
      search_str = str.sub(/(?:\s*\[(#{re_locales})\]\s*)(?:\[ID=(\d+)*\]\s*)\z/m){ lcode = $1; model_id = $2; "" }
      model_id = (model_id.blank? ? nil : model_id.to_i)  # nil or Integer
      [search_str, lcode, model_id] 
    end

    # Merge Translations with is_orig=true
    #
    # 1. If the languages are the same, the unselected one is deleted (title, alt_title, and all).
    #    1. However, if the unselected one has both `title` and `alt_title`, and the selected one has only `title`, the `alt_title` is transferred to `alt_title` of the selected one.
    # 2. If the languages are different, the unselected one is deleted at once.
    #
    # @note Instance variable +@to_index+ **must be present** so +models[@to_index]+ remains
    #   i.e., its primary ID survives, though some or even all the contents
    #   may be overwritten.
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def merge_lang_orig(models)
      index2use = merge_param_int(:lang_orig, fallback: models[0])
      origs = [0, 1].map{|i| models[i].orig_translation}
      if origs[0].langcode == origs[1].langcode &&
          origs[index2use].alt_title.blank? &&
         !origs[other_index(index2use)].alt_title.blank?
        to_copies = %i(alt_title alt_ruby alt_romaji).map{|metho|
          [metho, origs[other_index(index2use)].send(metho)]
        }.to_h
      end
      id_destroyed = origs[other_index(index2use)].id
      origs[other_index(index2use)].destroy!

      # alt_title etc are copied.
      if to_copies
        to_copies.each_pair do |metho, val|
          origs[index2use].send(metho.to_s+"=", val)
        end
      end

      if origs[index2use].weight != 0
        artrans = _weight_sorted_translations(models, origs[index2use].langcode)
        if artrans[0].id != origs[index2use]
          # The weight of is_orig=true is not the lowest.
          # If the smallest weight among others is 0, adjusts it.
          if artrans[0].weight && artrans[0].weight <= 0 && artrans[0].id != id_destroyed  # id-check is necessary; otherwise caching may do something unexpected!
            artrans[0].weight =
              if artrans[1] && artrans[1].weight
                artrans[1].weight.quo(2)
              else
                100
              end
begin
            artrans[0].save!
rescue ActiveRecord::RecordInvalid
  logger.error "(#{__method__}) ERROR(ActiveRecord::RecordInvalid): DEBUG: org=#{origs[index2use]}, artrans=#{artrans.inspect}"
  raise
end
          end

          origs[index2use].weight = artrans[0].weight.quo(2)
        end
      end

      origs[index2use].translatable = models[@to_index]
      origs[index2use].save!
    end

    # Merge Translations
    #
    # If two of them have same weights and langcode (it should never happen
    # between the Translations for the same {BaseWithTranslation}, but because we are
    # handling two {BaseWithTranslation}-s, it can happen), one of the weights
    # must be adjusted before merging multiple {Translation}, that is,
    # unifying their parent into one {BaseWithTranslation}.
    #
    # @note Instance variable +@to_index+ **must be present** so +models[@to_index]+ remains
    #   i.e., its primary ID survives, though some or even all the contents
    #   may be overwritten.
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def merge_lang_trans(models)
      I18n.available_locales.each do |lang_sym|
        lcode = lang_sym.to_s
        artrans = _weight_sorted_translations(models, lcode)

        prev = nil
        artrans.reverse.each_with_index do |etra, ind|  # etra: Each_TRAnslation
          allsames = artrans[0..(-ind-2)].find_all{|eac| eac.langcode == etra.langcode && eac.title == etra.title} if artrans.size > ind+1
          if allsames && !allsames.empty?
            etra.destroy!   # Because there is/are duplicated Translation with a lower weight (or lower priority with the same weight).
            next  # prev stays the same.
          end

          if ind < artrans.size-1 && artrans[-ind-2].weight == etra.weight && !etra.is_orig
            if !prev || !prev.weight
              (etra.weight ? (etra.weight += 10) : (etra.weight = 100))
            else
              cand = [(etra.weight + prev.weight).quo(2), etra.weight+10].min
              etra.weight = ((cand.to_i > etra.weight) ? cand.to_i : cand)
            end
          end
          etra.translatable = models[@to_index]
          etra.save!
          prev = etra
        end
      end
    end


    # Merge Engage and adjust dependent Harami1129
    #
    # Some Engages will have different {Engage#music}, {Engage#artist} and contribution.
    # Some (rare) Engages that belong to Music to be deleted remain unchanged
    # and as a result will be cascade-deleted.
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def merge_engage_harami1129(models)
      model_underscore = models[0].class.name.underscore
      index2use = merge_param_int(:engage)  # defined in base_merges_controller.rb
      engages_to_copy =       models[index2use].engages
      engages_to_supplement = models[other_index(index2use)].engages

      engages_to_copy.each do |eng|
        eng.update!(model_underscore.to_sym => models[@to_index])
      end

      engages_to_supplement.each do |eng|
        hows = engages_to_copy.where(engage_how: eng.engage_how)
        if hows.exists?
          hs_other = 
            if "music" == model_underscore
              {artist: eng.artist}
            else
              {music:  eng.music}
            end
          if hows.where(hs_other).exists?
            # The same Artist (if processing for Music) with the same EngageHow exists.
            # So, this record will be cascade-deleted when the Music/Artist is deleted.
            # As a result, year and note in this record are discarded.
            #
            # If it has dependent Harami1129(s), its deletion would raise an Error.
            eng_to_switch_to = hows.where(hs_other).first
            eng.harami1129s.each do |harami1129|
              harami1129.update!(engage: eng_to_switch_to)
            end
            next
          else
            eng.contribution = nil
          end
        end
        eng.send(model_underscore+"=", models[@to_index])
        eng.save!
      end
    end

    # Overwrite the one of attributes of model, unless it is nil (in which case the other is used).
    #
    # * prefecture_place: 'prefecture_place',
    # * genre: 'genre',
    # * year: 'year',
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    # @param metho [Symbol]
    def merge_overwrite(models, metho)
      attr = ((metho == :prefecture_place) ? :place : metho).to_s
      content = nil
      index2use = merge_param_int(metho)
      [index2use, other_index(index2use)].each do |ind|
        (content = models[ind].send(attr)) && break
      end
      models[@to_index].send(attr+"=", content)
    end

    # notes are, unlike other parameters, simply merged.
    #
    # The note for the preferred comes first.
    # In an unlikely case of both notes being identical, one of them is discarded.
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def merge_note(models)
      models[@to_index].note = [models[@to_index], models[other_index(@to_index)]].map{|i| i.note || ""}.uniq.join(" ")
    end

    # Older one is adopted
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def merge_created_at(models)
      models[@to_index].created_at = models.map(&:created_at).min
    end

    # rendering for update
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    def _update_render(models)
      model_name = models[0].class.name
      model_underscore = model_name.underscore
      path_show = model_underscore+"_path"  # music_path etc

      mu_to = models[@to_index]
      mu_other = models[other_index(@to_index)]
      if !mu_to.errors.any? && mu_other.destroyed?
        return respond_to do |format|
          msg = sprintf "#{model_name.pluralize} were successfully merged."
          format.html { redirect_to send(path_show, mu_to), success: msg }
          format.json { render :show, status: :ok, location: mu_to }
        end
      end

      ## Somehow merging failed!  Error...
      errmsgs = []
      [@to_index, other_index(@to_index)].each do |ind|
        errmsgs += models[ind].errors.full_messages if !models[ind].destroyed?
      end
      logger.error "ERROR: Merge-#{model_name.pluralize} somehow failed with errors.full_messages="+errmsgs.inspect

      errmsgs_safe = errmsgs.map{|i| ERB::Util.html_escape(i)}.join("  ")
      msg0 = "Failed to merge #{model_name.pluralize}"
      if !mu_other.destroyed?
        msg0 << " with " + view_context.link_to("ID=#{mu_other.id}", send(path_show, mu_other))
      end
      msg1 = (msg0 + '.  ' + errmsgs_safe).html_safe
      opts = flash_html_safe(alert: msg1)  # defined in /app/controllers/application_controller.rb

      respond_to do |format|
        hsstatus = {status: :unprocessable_entity}
        format.html { redirect_to send(path_show, mu_to), **(hsstatus.merge opts) }
        format.json { render json: errmsgs, **hsstatus }
      end
    end

    # Helper method for "edit" Form
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    #   and the other will be destroyed.
    # @return [CheckedDisabled] {CheckedDisabled#contents} is a 2-element Array of the String to print.
    def _non_orig_translations_checked_disabled(models)
      contents = _translations_htmls(models)
      i_checked = (contents.find_index{|i| !i.blank?} || -1)
      disabled  = (1 == contents.find_all{|i| !i.blank?}.size)
      CheckedDisabled.new(checked_index: i_checked, disabled: disabled, contents: contents)
    end

    # @return [Integer] 1 if 0 is given, or vice versa
    def other_index(my_index)
      my_index ^ 1   # ((my_index.to_i == 0) ? 1 : 0)
    end

    # Returns the weight-sorted Translations for a langcode
    #
    # Sorting is based on the {Translation} weights and User's selection.
    #
    # @param models [Array<BaseWithTranslation>] 2-element Array. Index of +@to_index+ remains
    # @param [Stroing] locale
    # @return [Array<Translation>]
    def _weight_sorted_translations(models, langcode)
      index2use = merge_param_int(:lang_trans, fallback: models[0])
      artrans = []
      [0, 1].each do |ind|
        artrans += models[ind].translations.find_all{|i| langcode.to_s == i.langcode}.map{|eat| [ind, eat]} 
      end
      artrans.sort!{|a, b|
        cmp = (a[1].weight || 0) <=> (b[1].weight || 0)
        next cmp if 0 != cmp
        ((a[0] == index2use) ? 0 : 1) <=> ((b[0] == index2use) ? 0 : 1)  # Translation#weight are the same.
      }
      # NOTE: artrans is an Array of Translation, sorted according to the weight and User's selection
      artrans.map{|i| i[1] }
    end
end
