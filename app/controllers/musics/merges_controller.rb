class Musics::MergesController < BaseMergesController
  before_action :set_music,  only: [:new]
  before_action :set_musics, only: [:edit, :update]

  # Preparation routine.
  # @return [Array<String, String, Integer>] e.g., ["Queen", "en", 123]
  def self.prepare_autocomplete_musics(str)
    re_locales = I18n.available_locales.map(&:to_s).join("|")
    lcode = nil
    model_id = nil
    search_str = str.sub(/(?:\s*\[(#{re_locales})\]\s*)(?:\[ID=(\d+)*\]\s*)\z/m){ lcode = $1; model_id = $2; "" }
    model_id = (model_id.blank? ? nil : model_id.to_i)  # nil or Integer
    [search_str, lcode, model_id] 
  end


  # @raise [ActionController::UrlGenerationError] if no Music ID is found in the path.
  def new
  end

  # @raise [ActionController::UrlGenerationError] if no Music ID is found in the path.
  # @raise [ActionController::ParameterMissing] if the other Music ID is not specified (as GET).
  def edit
    if @musics.size != 2
      msg = 'No Music matches the given one. Try a different title.'
      respond_to do |format|
        format.html { redirect_to musics_new_merge_users_path(@musics[0]), alert: msg }
        format.json { render json: {error: msg}, status: :unprocessable_entity }
      end
    end
  end

  def update
    raise 'This should never happen - necessary parameter is missing.' if @musics.size != 2
    @to_index = merge_params[:to_index].to_i
    begin
      ActiveRecord::Base.transaction do
        merge_lang_orig
        merge_lang_trans
        merge_engage_harami1129
        %i(prefecture_place genre year).each do |metho| 
          merge_overwrite metho
        end
        merge_note
        merge_harami_vid_music_assoc

        @musics[@to_index].save!
        @musics[other_index(@to_index)].reload  # Without this HaramiVidMusicAssoc is cascade-destroyed!
        @musics[other_index(@to_index)].destroy!
        #raise ActiveRecord::Rollback, "Force rollback." if ...
      end
    rescue
      raise ## Transaction failed!  Rolled back.
    end

    respond_to do |format|
      mu_to = @musics[@to_index]
      mu_other = @musics[other_index(@to_index)]
      if !mu_to.errors.any? && mu_other.destroyed?
        msg = sprintf 'Musics was successfully merged.'
        format.html { redirect_to music_path(mu_to), success: msg }
        format.json { render :show, status: :ok, location: mu_to }
      else
        ## Somehow failed!
        errmsgs = []
        [@to_index, other_index(@to_index)].each do |ind|
          errmsgs += @musics[ind].errors.full_messages if !@musics[ind].destroyed?
        end
        logger.error "ERROR: Merge-Musics somehow failed with errors.full_messages="+errmsgs.inspect

        errmsgs_safe = errmsgs.map{|i| ERB::Util.html_escape(i)}.join("  ")
        msg0 = 'Failed to merge Musics'
        if !mu_other.destroyed?
          msg0 << " with " + view_context.link_to("ID=#{mu_other.id}", music_path(mu_other))
        end
        msg1 = (msg0 + '.  ' + errmsgs_safe).html_safe
        opts = flash_html_safe(alert: msg1)  # defined in /app/controllers/application_controller.rb

        hsstatus = {status: :unprocessable_entity}
        format.html { redirect_to music_path(mu_to), **(hsstatus.merge opts) }
        format.json { render json: errmsgs, **hsstatus }
      end
    end
  end

  private
    # Use callback for setup for new
    def set_music
      @music = Music.find(params[:id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_musics
      @musics = []
      @musics << Music.find(params[:id])
      begin
        @musics << get_other_music
      rescue ActiveRecord::RecordNotFound
        # Specified Title for Edit is not found.  For update, this should never happen.
        # As a result, @musics.size == 1
      end
    end

    # Only allow a list of trusted parameters through.
    def merge_params
      params.require(:music).permit(*FORM_MERGE.keys)
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
    def merge_param_int(key)
      ((ret = merge_params[key]).blank? ? merge_params[FORM_MERGE[:to_index]] : ret).to_i
    end

    # Gets the other Music ID, which is either
    # params[:other_music_id] or params[:music][:other_music_id]
    #
    # @return [Music]
    # @raise [ActionController::ParameterMissing] if neither exists.
    # @raise [ActiveRecord::RecordNotFound] if :other_music_id is not given and no Music matches :other_music_title
    def get_other_music
      key = :other_music_id
      other_id = (params.permit(key)[key] || params.require(:music).permit(key)[key])
      return Music.find(other_id) if !other_id.blank?

      key = :other_music_title
      mu_title = params.require(:music).permit(key)[key]
      return Music.find(nil) if !mu_title || mu_title.strip.blank?  # raises ActiveRecord::RecordNotFound

      search_str, lcode, model_id = self.class.prepare_autocomplete_musics(mu_title)
      return Music.find(model_id) if model_id

      armusic = @musics[0].select_translations_partial_str_except_self(
        :titles, search_str,
        langcode: lcode
      ).map{|i| i.translatable}.uniq

      return Music.find(nil) if armusic.empty?  # raises ActiveRecord::RecordNotFound
      if armusic.size > 1
        if flash[:warning]
          flash[:warning] << "  " 
        else
          flash[:warning] = ""
        end
        flash[:warning] << sprintf("Found more than 1 Music for word=(%s).", mu_title.strip)
      end
      armusic.first
    end

    # @return [Integer] 1 if 0 is given, or vice versa
    def other_index(my_index)
      ((my_index.to_i == 0) ? 1 : 0)
    end

    # Merge Translations with is_orig=true
    #
    # 1. If the languages are the same, the unselected one is deleted (title, alt_title, and all).
    #    1. However, if the unselected one has both `title` and `alt_title`, and the selected one has only `title`, the `alt_title` is transferred to `alt_title` of the selected one.
    # 2. If the languages are different, the unselected one is deleted at once.
    #
    def merge_lang_orig
      index2use = merge_param_int(:lang_orig)
      origs = [0, 1].map{|i| @musics[i].orig_translation}
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
        artrans = weight_sorted_translations(origs[index2use].langcode)
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

      origs[index2use].translatable = @musics[@to_index]
      origs[index2use].save!
    end

    # Merge Translations
    #
    # If two of them have same weights and langcode (it should never happen
    # between the Translations for the same Music, but because we are
    # handling two Musics, it can happen).
    #
    def merge_lang_trans
      I18n.available_locales.each do |lang_sym|
        lcode = lang_sym.to_s
        artrans = weight_sorted_translations(lcode)

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
          etra.translatable = @musics[@to_index]
          etra.save!
          prev = etra
        end
      end
    end

    # Merge Engage and adjust dependent Harami1129
    #
    # Some Engages will have different {Engage#music} and contribution.
    # Some (rare) Engages that belong to Music to be deleted remain unchanged
    # and as a result will be cascade-deleted.
    def merge_engage_harami1129
      index2use = merge_param_int(:engage)
      engages_to_copy =       @musics[index2use].engages
      engages_to_supplement = @musics[other_index(index2use)].engages

      engages_to_copy.each do |eng|
        eng.update!(music: @musics[@to_index])
      end

      engages_to_supplement.each do |eng|
        hows = engages_to_copy.where(engage_how: eng.engage_how)
        if hows.exists?
          if hows.where(artist: eng.artist).exists?
            # The same Artist with the same EngageHow exists. So, this record will be
            # cascade-deleted when the Music is deleted. As a result, year and note
            # in this record are discarded.
            #
            # If it has dependent Harami1129(s), its deletion would raise an Error.
            eng_to_switch_to = hows.where(artist: eng.artist).first
            eng.harami1129s.each do |harami1129|
              harami1129.update!(engage: eng_to_switch_to)
            end
            next
          else
            eng.contribution = nil
          end
        end
        eng.music = @musics[@to_index]
        eng.save!
      end
    end

    # Overwrite the model with one of them, unless it is nil (in which case the other is used).
    #
    # * prefecture_place: 'prefecture_place',
    # * genre: 'genre',
    # * year: 'year',
    #
    # @param metho [Symbol]
    def merge_overwrite(metho)
      attr = ((metho == :prefecture_place) ? :place : metho).to_s
      content = nil
      index2use = merge_param_int(metho)
      [index2use, other_index(index2use)].each do |ind|
        (content = @musics[ind].send(attr)) && break
      end
      @musics[@to_index].send(attr+"=", content)
    end

    # notes are, unlike other parameters, simply merged.
    #
    # The note for the preferred comes first.
    # In an unlikely case of both notes being identical, one of them is discarded.
    def merge_note
      @musics[@to_index].note = [@musics[@to_index], @musics[other_index(@to_index)]].map{|i| i.note || ""}.uniq.join(" ")
    end

    def merge_harami_vid_music_assoc
      @musics[other_index(@to_index)].harami_vid_music_assocs.each do |hvma|
        hvma.update!(music: @musics[@to_index])
      end
    end

    # Returns the weight-sorted Translations for a langcode
    #
    # @param [Stroing] locale
    # @return [Array<Translation>]
    def weight_sorted_translations(langcode)
      index2use = merge_param_int(:lang_trans)
      artrans = []
      [0, 1].each do |ind|
        artrans += @musics[ind].translations.find_all{|i| langcode.to_s == i.langcode}.map{|eat| [ind, eat]} 
      end
      artrans.sort!{|a, b|
        cmp = (a[1].weight || 0) <=> (b[1].weight || 0)
        next cmp if 0 != cmp
        ((a[0] == index2use) ? 0 : 1) <=> ((b[0] == index2use) ? 0 : 1)  # Translation#weight are the same.
      }
      artrans.map{|i| i[1] }
      # NOTE: artrans is an Array of Translation, sorted according to the weight and User's selection
    end
end
