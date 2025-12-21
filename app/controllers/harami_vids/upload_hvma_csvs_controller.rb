# coding: utf-8

# Controller to populate an uploaded file to the DB
class HaramiVids::UploadHvmaCsvsController < ApplicationController
  include ModuleUploadCsv

  # This sets @harami_vid
  before_action :authorize_for_edit, only: [:create]

  # POST /harami_vid_music_assocs/upload_hvma_csvs
  def create
    render_path = 'harami_vids/show'
    uploaded_io, csv_direct = upload_hvma_csvs_params.slice(:file, :csv_direct).values  # IO object, String.

    if uploaded_io.blank? && csv_direct.blank? || uploaded_io.present? && csv_direct.present?
      @harami_vid.errors.add :csv_direct, " Either of uploading file or direct-input must be present, NOT neither or both."
      respond_to do |format|
        hsstatus = {status: :unprocessable_content}
        format.html { render template: render_path,    **hsstatus }
        format.json { render json: @harami_vid.errors, **hsstatus }
      end
      return
    end

    hsret = populate_csv_file((uploaded_io || csv_direct), in_redirect_path: harami_vid_url(@harami_vid)){ |csv_str|  # defined in ModuleUploadCsv
      # the latter path should be new_music_url, too; but leaving it as musics_path for now for the sake of testing...
      @harami_vid.populate_hvma_csv(csv_str)
    }
    return if !hsret

    # Here, @changes is either (nil, false, base::ResultLoadCsv); nil if not evaluated and false for CSV-format error; RLC#music_ja returns an Array
    @input_lines, @changes, @csv, @artists, @musics, @hvmas, @amps, @stats = hsret.slice(*(%i(input_lines changes csv artists musics hvmas amps stats))).values
    @unimported_csvs     = get_unimported_csvs
    @missing_musics_csv  = get_missing_musics_csv  # always String, maybe ""

    # sets flash messages based on HaramiVid#alert_messages
    set_flash_messages

    respond_to do |format|
      format.html { render template: render_path, status: :ok }
      format.json { render template: render_path, status: :ok, location: @harami_vid }
    end
  end

  protected

  private
    def upload_hvma_csvs_params
      params.require(:upload_hvma_csv).permit(:file, :csv_direct)
    end

    def authorize_for_edit
      @main_record = @harami_vid = HaramiVid.find(params[:harami_vid_id])

      if !current_user
        head :unauthorized
        raise ActionController::RoutingError.new('Not authenticated...')
      elsif !can?(:edit, @harami_vid)
        logger.info sprintf('(%s#%s) User (ID=%d) access forbidden to HaramiVid(ID=%d)', self.class.name, __method__, current_user.id, @harami_vid.id)
        render(file: File.join(Rails.root, "public/403.html"), status: :forbidden, layout: false)
        # render status: :forbidden
        raise ActionController::RoutingError.new('Not authorized...')
      end
    end

    # Sets flash messages of :notice and :warning
    def set_flash_messages
      add_flash_message(:success, "CSV uploaded.")  # defined in application_controller.rb
      if @input_lines.size >= MAX_LINES
        add_flash_message(:warning, "WARNING: More than #{MAX_LINES} lines in the input CSV is ignored!")  # defined in application_controller.rb
      end

      ### This may (or frequently for large data) raise ActionDispatch::Cookies::CookieOverflow
      # @harami_vid.alert_messages.each_pair do |etype, eary|
      #   eary.each do |msg|
      #     add_flash_message(etype, msg)  # defined in application_controller.rb
      #   end
      # end

      add_flash_message(:notice, msg_stats_summary)  # defined in application_controller.rb
    end

    # Build a message for Statistics
    def msg_stats_summary
      if @csv.compact.size != @stats.attempted_rows
        logger.error "ERROR: Inconsistent stats in CSV upload (HaramiVid#populate_hvma_csv): CSV(#{@csv.compact.size}) != Stats(#{@stats.attempted_rows})"
      end
      if @stats.attempted_rows != @stats.success_rows + @stats.rejected_rows + @stats.unchanged_rows
        logger.error "ERROR: Inconsistent stats in attempted_rows and three categorization in CSV upload (HaramiVid#populate_hvma_csv): Attempted #{@stats.attempted_rows} != Success(#{@stats.success_rows}) + Rejected(#{@stats.rejected_rows}) + Unchanged(#{@stats.unchanged_rows})"
      end

      stats_models = @stats.stats.select{ |_, value| value.respond_to?(:each_pair) }
      item_keys = ModuleCsvAux::StatsSuccessFailure.initial_hash_for_key.except("destroyed").keys

      msg_detail = stats_models.map{ |ek_top, ehs|
        next nil if "engages" == ek_top.to_s
        msg = item_keys.map{ |ek| ehs[ek].to_s }.join("/")  # TODO: stats for created and updated do not look right.....
        sprintf "%s (%s)", ek_top.singularize.camelize, msg
      }.compact.join("; ")

      sprintf "Summary: Out of %d CSV rows found in %d lines of input file, %d rows found no matching Music, %d rows matched but resulted in no changes, %d models (NOT rows) accepeted for change on DB records.  Total number of model-records attempted to change is %d; %d created, %d updated, %d failed.  Detail(%s): %s.",
              @stats.attempted_rows,
              @input_lines.size,
              @stats.rejected_rows,
              @stats.unchanged_rows,
              @stats.success_rows,
              @stats.attempted_models,
              stats_models.values.sum{ |eh| eh[:created] },
              stats_models.values.sum{ |eh| eh[:updated] },
              stats_models.values.sum{ |eh| eh[:failed] },
              item_keys.join("/"),
              msg_detail
    end


    # Returns CSV rows that have caused erroneous results, such as, unidentified Music on DB
    #
    # @return [String] Never nil.
    def get_unimported_csvs
      ret = @input_lines.map.with_index{ |input_line, iline|
        next input_line if @csv[iline].blank? && (false == @changes[iline])  # CSV-format error
        next if @csv[iline].blank?                # Comment or blank line
        next input_line if @musics[iline].blank?  # CSV-row, but Music is NOT identified
        nil
      }.compact.join("\n")
      ret.present? ? ret+"\n" : ret
    end


    # Builds and returns a CSV of the missing Musics
    #
    # @return [String] Never nil
    def get_missing_musics_csv
      # Among hsmap_hvid_csv, %w(hvma_note event_item_id memo) are ignored as they are irrelevant to Music model instances.
      hsmap_hvid_csv = array_to_hash(HaramiVid::MUSIC_CSV_FORMAT).with_indifferent_access  # defined in ModuleCommon
      hsmap_mu_csv   = array_to_hash(Music::MUSIC_CSV_FORMAT).with_indifferent_access      # defined in ModuleCommon

      default_objs = {
        genre:      Genre.default(:HaramiVid).title(langcode: :en),
        engage_how: EngageHow.default(:HaramiVid).title(langcode: :en),
        country:    nil, # Country.unknown.title(langcode: :en),  # This should be auto-determined in CSV-import.
      }.with_indifferent_access

      @csv.map.with_index{ |csv, iline|  # The last few lines may be missing if they are not imported to CSV.
        next if csv.blank?
        next if @musics[iline].present?
        arrow4csv = []
        artist_titles = {}.with_indifferent_access  # reset for every Music
        Music::MUSIC_CSV_FORMAT.each do |mu_csv_key| 
          arrow4csv[hsmap_mu_csv[mu_csv_key]] = 
            case mu_csv_key.to_s
            when "row"
              # Each row now begins with "Timing=nil;" etc
              sprintf("Timing=%s", csv["timing"].inspect) + # For user information
                ((s=csv["header"]) ? ";"+s : "")
            when *(%w(music_ja music_en year))
              csv[mu_csv_key]
            when "memo"
              csv["music_note"]
            when *(%w(artist_ja artist_en))
              artist4music = csv["artist"]
              if artist4music.blank?
                nil
              elsif artist4music.respond_to?(:gsub)
                mu_key = "artist_" + guess_lang_code(artist4music)  # defined in ModuleCommon
                (mu_key == mu_csv_key.to_s) ?  artist4music : nil
              else  # Artist model instance.
                # Initializes artist_titles for this Music if not yet.
                artist_titles = artist4music.title_or_alt_hash([:ja, :en], ensure_lc: "ja") if artist_titles.empty? # defined in BaseWithTranslation

                langcode = mu_csv_key.to_s.split(/_/)[-1]  # ja or en
                artist_titles[langcode]
              end
            when "langcode"
              (csv["music_ja"].present? ? "ja" : "en")
            when *(%w(genre how country))
              default_objs[mu_csv_key]
            when *(%w(ruby romaji))
              # ignores
            else
              raise "Contact the code developer: key=#{mu_csv_key.inspect}."   # Music::MUSIC_CSV_FORMAT is updated???
            end
        end
        arrow4csv.present? ? arrow4csv.to_csv : nil
      }.compact.join
    end  # def missing_musics_csv
end
