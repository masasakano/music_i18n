
# Superclass of Musics::MergesController etc
class BaseMergesController < ApplicationController
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
      key = "other_"+mo_name +"_id"
      other_id = (params.permit(key)[key] || params.require(mo_name).permit(key)[key])
      return mo_class.find(other_id) if !other_id.blank?

      key = "other_"+mo_name+"_title"
      mo_title = params.require(mo_name).permit(key)[key]
      return mo_class.find(nil) if !mo_title || mo_title.strip.blank?  # raises ActiveRecord::RecordNotFound

      search_str, lcode, model_id = prepare_autocomplete_model(mo_title)
      return mo_class.find(model_id) if model_id

      armodel = model.select_translations_partial_str_except_self(
        :titles, search_str,
        langcode: lcode
      ).map{|i| i.translatable}.uniq

      return mo_class.find(nil) if armodel.empty?  # raises ActiveRecord::RecordNotFound
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
          if artrans[0].weight && artrans[0].weight <= 0
            artrans[0].weight =
              if artrans[1] && artrans[1].weight
                artrans[1].weight.quo(2)
              else
                100
              end
            artrans[0].save!
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
