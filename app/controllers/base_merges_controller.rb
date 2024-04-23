
# Superclass of Musics::MergesController etc
#
# {CheckedDisabled} defined in +/lib/checked_disabled.rb+ is a key helper class.
#
# Child classes are so far {Musics::MergesController} and {Artists::MergesController} .
class BaseMergesController < ApplicationController
  # GET parameter "to_submit"
  #
  # If this is not specified in "new", no submit button will be displayed.
  PARAM_GET_SUBMIT = "to_submit"

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

    # Returns HTML of Translations to display in Table merge-edit, where Translations are sorted.
    #
    # @param model [BaseWithTranslation] Artist or Music. Translation of is_orig=true is ignored.
    # @return [String] html_safe HTML
    def _translations_html(model)
      # exist_editable = em.translations.where.not(id: em.orig_translation.id).any?{|et| can?(:ud, et)}
      ### I have decided not to check ability... too complicated!
      _translations_html_core(model.translations.where(is_orig: false).or(model.translations.where(is_orig: nil)))
    end

    # Returns HTML of Translations from Array in "hsmodel" returned from {BaseWithTranslation#merge_other}
    #
    # @param ar_trans [Array<Translation>] Returned from {BaseWithTranslation#merge_other}
    # @param reject_orig: [Bool] if true (Def), Translation with is_orig=true is rejected in the returned HTML.
    # @return [String] html_safe HTML
    def _translations_html_from_ary(ar_trans, reject_orig: true)
      _translations_html_core(reject_orig ? ar_trans.reject{|i| i.is_orig} : ar_trans )
    end

    # @param artrans [Relation<Translation>, Array<Translation>]
    # @return [String] html_safe HTML
    def _translations_html_core(artrans)
      artrans.sort{|a, b|
        # Sorted in the order of Language (langcode/locale) and weight
        w = ((I18n.available_locales.find_index(a.langcode.to_sym) || Float::INFINITY) <=>
             (I18n.available_locales.find_index(b.langcode.to_sym) || Float::INFINITY))
        next w if w != 0
        (a.weight || Float::INFINITY) <=> (b.weight || Float::INFINITY)
      }.map{ |et|
        # next if et.langcode == orig_trans.langcode
        ERB::Util.html_escape(sprintf("[%s] %s / %s", et.langcode, et.title, et.alt_title))
      }.join("&nbsp;&nbsp;<br>").html_safe
    end

    # set @to_index
    #
    # Either in a form of params[:to_index] or params[:artist|:music][:to_index]
    def set_to_index
      keyi = FORM_MERGE[:to_index]
      case action_name.to_sym
      when :edit
        @to_index = params[keyi]  # params.permit(keyi)[keyi] would return the same (but no point to do so)
        if !@to_index && (s=self.class::MODEL_SYM; params.has_key?(s))
          @to_index = params.require(s)[keyi]  # no need of "permit" for simple accessing.
        end
        @to_index   = @to_index.presence
        @to_index &&= @to_index.to_i  # nil or Integer
      when :update
        @to_index = merge_params[keyi].to_i
      else
        raise "Unexpected action_name (#{action_name})..."
      end
    end

    # Only allow a list of trusted parameters through.
    #
    # @param fallback [Class, BaseWithTranslation, String, Symbol] like +:music+
    def merge_params(fallback: model=nil)
      prm = (self.class.const_defined?(:MODEL_SYM) && self.class::MODEL_SYM ||  # e.g., :music
             model.respond_to?(:name) && model.name.underscore ||
             model.respond_to?(:downcase) && model.downcase ||
             model.respond_to?(:to_sym) && model.to_sym )
      params.require(prm).permit(PARAM_GET_SUBMIT, *FORM_MERGE.keys)
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
        logger.error "(#{File.basename __FILE__}:#{__method__}): Neither #{key_i.to_sym.inspect} nor #{key_t.to_sym.inspect} is found, which should never happen through UI: params=#{params.inspect}"
        return mo_class.find(nil) if !mo_title || mo_title.strip.blank?  # raises ActiveRecord::RecordNotFound
      end

      retmodel = self.class.other_model_from_ac(model, mo_title, controller: self)
      if retmodel
        retmodel
      else
        logger.error "ERROR(#{__method__}): Neither #{key_i.to_sym.inspect} nor the matching content for #{key_t.to_sym.inspect} is found, which should never happen through UI: params=#{params.inspect}"
        mo_class.find(nil)  # raises ActiveRecord::RecordNotFound
      end
    end

    # Other model from the auto-completed string, excluding self
    #
    # flash warning may be added.
    #
    # If the caller has no competing model (of Artist or Music),
    # just pass me an initilized model (see Example).
    #
    # @example from another Controller
    #    model = BaseMergesController.other_model_from_ac(Artist.new, search_word, controller: self)
    #    raise if !model
    #
    # @param model [BaseWithTranslation] either Artist or Music
    # @param search_word [String]
    # @param controller: [ApplicationController] for flash message. Mandatory
    # @return [BaseWithTranslation, NilClass] nil if not found
    def self.other_model_from_ac(model, search_word, controller: )
      armodel = model.candidate_bwts_from_ac_str(search_word)
      if armodel.empty?
        return nil
      elsif armodel.size > 1
        if controller.flash[:warning]
          controller.flash[:warning] << "  " 
        else
          controller.flash[:warning] = ""
        end
        controller.flash[:warning] << sprintf("Found more than 1 %s for word=(%s); the first one is adopted.", model.class.name, search_word.strip)
      end
      armodel.first
    end


    # Arguments from the arguments of the parent method
    #
    # @param model [BaseWithTranslation]
    # @param to_index [Integer, String, NilClass] In default, taken from params()
    # @return [Array<Integer, Hash<Symbol, Symbol>] [to_index, priorities]
    def _build_priorities(model, to_index=nil)
      hs_params = (s=self.class::MODEL_SYM; params.has_key?(s) ? params.require(s) : nil) 
      hs_params &&= hs_params.permit(*FORM_MERGE)  # sanitizing.  NOTE: Even without this, hs_params[:sex] etc would return a user-set value as expected because they are simply flagged as "unpermitted" and nothing stops you accessing them.
      to_index ||= (@to_index || (hs_params ? hs_params.permit(:to_index)[:to_index].to_i : 0))  # @to_index should be set at set_to_index() called from each Controller

      priorities = { default: :self }
      FORM_MERGE.each_pair do |fkey, fval|
        next unless %w(lang_orig lang_trans engage prefecture_place birthday).include?(fkey) || model.respond_to?(fkey)
        prm_val = (hs_params ? hs_params[fval] : nil)
        next if prm_val.blank?
        k = (("engage" == fval) ? :engages : fval.to_sym)  # NOTE: The key for FORM_MERGE and its value are :engage, but the key for "priorities" is :engages (!!). Inconsistent...
        priorities[k] = ((prm_val.to_i == to_index) ? :self : :other)
      end
      [to_index, priorities]
    end  # def _build_priorities(model, to_index)

    # Returns 3-element Array of Models-self/other and +priorities+ (Hash) from params()
    #
    # +priorities+ is passed to {BaseWithTranslation#merge_other}
    #
    # @param models [Array<BaseWithTranslation, BaseWithTranslation>]
    # @return [Array<Integer, Hash<Symbol, Symbol>] [to_index, priorities]
    def get_self_other_priorities(models)
      to_index, priorities = _build_priorities(models[0])

      mdl_self  = models[to_index]
      mdl_other = models[other_index(to_index)]
      [mdl_self, mdl_other, priorities]
    end  # def get_self_other_priorities(models)

    # Returns the merged model based on the given two models
    #
    # For {Music}, for example, the ID is taken from +params[:other_music_id]+
    # or +params[:music][:other_music_id]+
    #
    # For the returned model, singleton instance method ":hsmerged" is defined,
    # which returns a Hash containing information about the merged models
    # because otherwise the associated models may not be able to referred to.
    #
    # Refer to the manual of {BaseWithTranslation#merge_other} for the Hash;
    # the Hash is basically the returned object of the method.
    #
    # @example
    #   def update
    #     @merged_music = get_merged_model(@musics)  # defined in base_merges_controller.rb
    #     @merged_music.hsmerged[:trans][:original]  # => Translation of is_orig=true after merging
    #   end
    #
    # @param models [Array<BaseWithTranslation>] two-element Array.
    # @param to_index [Integer] 0 or 1 (the final ID after merged): params[self.class::MODEL_SYM][FORM_MERGE[:to_index]]
    # @return [BaseWithTranslation] the reference instance; singleton instance method ":hsmerged" is defined.
    # @raise [ActionController::ParameterMissing] if neither exists (which should never happen through UI).
    # @raise [ActiveRecord::RecordNotFound] if +:other_{model}_id+ is not given and no +Model+ matches +:other_{model}_title+
    def get_merged_model(models, to_index: nil)

      # reloading so that the records will stay (not be garbage-collected) after roll-back.
      def _touch_hsmerged(hsmerged)
        [:trans, :engage, :harami_vid_music_assocs].each do |gkey|
          next if !hsmerged[gkey]  # e.g., :harami_vid_music_assocs for Artist
          hsmerged[gkey].each_pair do |ek, ev|
            if ev.respond_to?(:reload)
              ev.reload
            elsif ev.respond_to?(:each)
              ev.each do |em|
                em.created_at
                #em.reload
              end
            else
              # Skip; e.g., :harami_vid_music_assocs > :n_destroyed
            end
          end
        end
      end # def _touch_hsmerged_key(hsmerged_gkey)

      #### Main routine ####

      merged = nil  # models[0].class.new()  # will be always overwritten.
      hsmerged = {}

      mdl_self, mdl_other, priorities = get_self_other_priorities(models)

      ActiveRecord::Base.transaction(requires_new: true) do  # "requires_new" option necessary for testing.
        hsmerged = mdl_self.merge_other(mdl_other, priorities: priorities, save_destroy: false, user: current_user)
        _touch_hsmerged(hsmerged)

        merged = mdl_self.dup
        merged.id = mdl_self.id

        raise ActiveRecord::Rollback, "Force rollback."
      end # ActiveRecord::Base.transaction(requires_new: true) do

      mdl_self.reload
      mdl_other.reload  # Without this, model.title_or_alt would not work well!

      hsmerged[:trans][:tr_html]      = _translations_html_from_ary( hsmerged[:trans][:remained])  # HTML to display in Table merge-edit
      hsmerged[:trans][:tr_orig_html] = _translations_html_from_ary([hsmerged[:trans][:original]], reject_orig: false)  # HTML to display in Table merge-edit

      merged.instance_variable_set(:@hsmerged, hsmerged)
      merged.define_singleton_method(:hsmerged){@hsmerged}

      merged
    end # def get_merged_model(models, to_index: nil)


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
           when :to_index
             CheckedDisabled.new(checked_index: _checked_index(ea_fmk, def_index: 0), disabled: false)
           when :lang_orig
             CheckedDisabled.new(chkmodels.map{|i| i.orig_translation}, checked_index: _checked_index(ea_fmk, def_index: 0))
           when :lang_trans
             _non_orig_translations_checked_disabled(chkmodels)
           when :engage
             torfs = chkmodels.map{|em| em.engages.exists? ? true : nil }
             CheckedDisabled.new(chkmodels, ea_fmk, checked_index: _checked_index(ea_fmk){torfs.find_index{|tf| tf}}, disabled: (1 == torfs.compact.size))
           when :prefecture_place
             CheckedDisabled.new(chkmodels, :place, checked_index: _checked_index(ea_fmk))
           when :genre, :year, :sex, :wiki_en, :wiki_ja
             CheckedDisabled.new(chkmodels, ea_fmk, checked_index: _checked_index(ea_fmk))
           when :birthday
             CheckedDisabled.new(chkmodels, :any_birthdate_defined?, checked_index: _checked_index(ea_fmk))
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

    # Determines checked index, considering (GET)-params
    #
    # Block is evaluated IF params() does not specify the index.
    #
    # @param key [String, Symbol] Hash Key
    # @param def_index: [Integer, NilClass] Default value. Lowest priority.
    # @yield [] If given, the returned value is used UNLESS the values is given in params()
    # @return [Integer, NilClass]
    def _checked_index(key, def_index: nil)
      s = self.class::MODEL_SYM
      k = FORM_MERGE[key]
      ret = ((params.key?(s) && params.require(s).permit(k)[k]) || (block_given? && yield) || def_index)
      (ret.blank? ? nil : ret.to_i)
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
      #contents = _translations_htmls(models)
      contents = models.map{|em| _translations_html(em)}
      i_checked = _checked_index(:lang_trans){(contents.find_index{|i| !i.blank?} || -1)}  # NOTE-to-Developer: "-1" should be replaced with nil?
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
    # @param langcode [String] locale
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

    # Returns the String message if an invalid model (ID or title) is specified to merge
    #
    # Otherwise nil.
    #
    # @param models [Array<BaseWithTranslation>] 2 or 3-element Array. (Original, Merging, Merged)
    # @param modelname [String] Singular Model name, e.g., "Artist"
    # @return [String, NilClass]
    def _msg_if_invalid_prm_in_merging(models, modelname)
      if !(2..3).cover?(models.size)
        "No #{modelname} matches the given one. Try a different title or ID."
      elsif models[0] == models[1]
        "Identical #{modelname.pluralize} specified. Try a different title or ID."
      else
        nil
      end
    end
end
