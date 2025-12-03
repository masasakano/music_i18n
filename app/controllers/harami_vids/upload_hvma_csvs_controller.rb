# coding: utf-8

# Controller to populate an uploaded file to the DB
class HaramiVids::UploadHvmaCsvsController < ApplicationController
  include ModuleUploadCsv
 
  # This sets @harami_vid
  before_action :authorize_for_edit, only: [:create]

  # POST /harami_vid_music_assocs/upload_hvma_csvs
  def create
    uploaded_io = upload_hvma_csvs_params[:file]  # IO object.

    hsret = populate_csv_file(uploaded_io, in_redirect_path: harami_vid_url(@harami_vid)){ |csv_str|
      # the latter path should be new_music_url, too; but leaving it as musics_path for now for the sake of testing...
      @harami_vid.populate_hvma_csv(csv_str)
    }
    return if !hsret

    @input_lines, @changes, @csv, @artists, @musics, @hvmas, @amps, @stats = hsret.slice(*(%i(input_lines changes csv artists musics hvmas amps stats))).values
    @musics.each_index do |iline|
      next if !hsret[:musics][iline]
      %i(musics hvmas amps).each do |k_model|
        next if !hsret[k_model][iline] || !hsret[k_model][iline].errors.any?
        prefix = sprintf("[%s/pID=%s] for Music (pID=%d: %s) ", hsret[k_model][iline].class.name, hsret[k_model][iline].id.inspect, hsret[:musics][iline].id, hsret[:musics][iline].best_translation)
        @harami_vid.transfer_errors(hsret[:musics][iline], prefix: prefix)
      end
    end

    set_flash_messages

    respond_to do |format|
      format.html { render 'harami_vids/show', status: :ok }
      format.json { render 'harami_vids/show', status: :ok, location: @harami_vid }
    end
  end

  protected

  private
    def upload_hvma_csvs_params
      params.require(:upload_hvma_csv).permit(:file)
    end

    def authorize_for_edit
      @harami_vid = HaramiVid.find(params[:harami_vid_id])

      if !current_user
        head :unauthorized
        raise ActionController::RoutingError.new('Not authenticated...')
      elsif !can?(:edit, @harami_vid)
        logger.info sprintf('(%s#%s) User (ID=%d) access forbidden to HaramiVid(ID=%d)', self.class.name, __method__, current_user.id, @harami_vid.id)
        render(:file => File.join(Rails.root, 'public/403.html'), :status => :forbidden, :layout => false)
        #render status: :forbidden
        raise ActionController::RoutingError.new('Not authorized...')
      end
    end

    # Sets flash messages of :notice and :warning
    def set_flash_messages
      add_flash_message(:success, "CSV uploaded.")  # defined in application_controller.rb
      if @input_lines.size >= MAX_LINES
        add_flash_message(:warning, "WARNING: More than #{MAX_LINES} lines in the input CSV is ignored!")  # defined in application_controller.rb
      end

      @harami_vid.alert_messages.each_pair do |etype, eary|
        eary.each do |msg|
          add_flash_message(etype, msg)  # defined in application_controller.rb
        end
      end
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
        msg = item_keys.map{ |ek| ehs[ek].to_s }.join("/")
        sprintf "%s (%s)", ek_top.singularize.camelize, msg
      }.compact.join("; ")

      sprintf "Summary: Out of %d CSV rows found in %d lines of input file, %d rows found no matching Music, %d rows resulted in no changes, %d rows accepeted for change on DB records.  Total number of model-records attempted to change is %d; %d created, %d updated, %d failed.  Detail(%s): %s.",
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
end
