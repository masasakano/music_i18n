# coding: utf-8
require 'open-uri'

class Harami1129sController < ApplicationController
  include ModuleCommon # for any_zenkaku_to_ascii

  before_action :set_harami1129, only: [:show, :edit, :update, :destroy]
  load_and_authorize_resource

  URI2FETCH = ENV['URI_HARAMI1129']
  if URI2FETCH
    URI_ROOT = URI2FETCH.split('/')[2].sub(/^www\./, '') 
  else
    logger.warn "Environmental variable URI2FETCH, thus URI_ROOT, is not defined."
  end

  INDEX_COLUMNS = [:singer, :song, :release_date, :title, :link_root, :link_time, :ins_singer, :ins_song, :ins_release_date, :ins_title, :ins_link_root, :ins_link_time, :ins_at, :note, :not_music, :destroy_engage, :human_check, :human_uncheck] # :harami_vid_id, :last_downloaded_at,

  # GET /harami1129s
  # GET /harami1129s.json
  def index
    harami1129_params(default: false)
    @harami1129s = Harami1129.all

    # May raise ActiveModel::UnknownAttributeError if malicious params are given.
    # It is caught in application_controller.rb
    @grid = Harami1129sGrid.new(grid_params) do |scope|
      scope.page(params[:page])
    end
  end

  # GET /harami1129s/1
  # GET /harami1129s/1.json
  def show
  end

  # GET /harami1129s/new
  def new
    @harami1129 = Harami1129.new
  end

  # GET /harami1129s/1/edit
  def edit
  end

  # POST /harami1129s
  # POST /harami1129s.json
  def create
    @harami1129 = Harami1129.new
    load_harami1129_from_form

    def_respond_to_format(@harami1129){ 
      @harami1129.errors.full_messages.empty? && @harami1129.save
    } # defined in application_controller.rb
  end

  # PATCH/PUT /harami1129s/1
  # PATCH/PUT /harami1129s/1.json
  def update
    load_harami1129_from_form

    def_respond_to_format(@harami1129, :updated){ 
      @harami1129.errors.full_messages.empty? && @harami1129.save
    } # defined in application_controller.rb
  end

  # DELETE /harami1129s/1
  # DELETE /harami1129s/1.json
  def destroy
    @harami1129.destroy
    respond_to do |format|
      format.html { redirect_to harami1129s_url, notice: 'Harami1129 was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  ############################################################

  protected

  def grid_params
    params.fetch(:harami1129s_grid, {}).permit!
  end

  #FORM_SUBMIT_NAME = 'FetchData'
  FORM_SUBMIT_INSERTION_WITHIN_NAME = 'InsertionWithin'
  #INSERT_FROM_HARAMI1129_COLUMNS = [FORM_SUBMIT_NAME.to_sym, :debug, :max_entries_fetch]
  DATA_GRID_COLUMN_ARGS = [:id, :singer, :link_time]  # Simple filtering
  DATA_GRID_COLUMN_OPTS = {release_date: [], created_at: []}  # Range filtering with two sets of dates

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_harami1129
      @harami1129 = Harami1129.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def harami1129_params(default: true)
      if default
        params.require(:harami1129).permit(*INDEX_COLUMNS)
      else
        if params[:harami1129s_grid]
          ActionController::Parameters.permit_all_parameters = true
          # params.permit(:commit, harami1129s_grid: {})
          # params[:harami1129s_grid].permit(*DATA_GRID_COLUMN_ARGS, **DATA_GRID_COLUMN_OPTS)
        else
          #params.permit(*(INDEX_COLUMNS+INSERT_FROM_HARAMI1129_COLUMNS))
          params.permit(*(INDEX_COLUMNS))
        end
      end
    end

    # Load @harami1129 from the form input for {#create} and {#update}
    #
    # An example params:
    #
    #   # <ActionController::Parameters {"singer"=>"AI", "song"=>"Story", "release_date(1i)"=>"2019", "release_date(2i)"=>"1", "release_date(3i)"=>"9", "title"=>"【即興ピアノ】即興ライブ！！", "link_root"=>"QqIpP4ZvQf4", "link_time"=>"430", "ins_singer"=>"AI", "ins_song"=>"Story", "ins_release_date(1i)"=>"2019", "ins_release_date(2i)"=>"1", "ins_release_date(3i)"=>"9", "ins_title"=>"【即興ピアノ】即興ライブ!!", "ins_link_root"=>"QqIpP4ZvQf4", "ins_link_time"=>"430", "ins_at(1i)"=>"2021", "ins_at(2i)"=>"1", "ins_at(3i)"=>"7", "ins_at(4i)"=>"19", "ins_at(5i)"=>"12", "ins_at(6i)"=>"25", "note"=>"", "not_music"=>"0", "destroy_engage"=>"0"} permitted: true>
    #   Also either "human_check" or "human_uncheck"
    #
    # @return [NilClass] @harami1129 is set.
    def load_harami1129_from_form
      hsprm = harami1129_params

      prm_not_music = hsprm[:not_music]
      prm_not_music &&= ((prm_not_music.to_i < 1) ? false : true)

      if helpers.get_bool_from_params hsprm[:destroy_engage]
        if !prm_not_music
          @harami1129.errors.add :destroy_engage, "needs to be coordinated with 'Not Music' - specify it to destory EngageId."
        else
          @harami1129.engage_id = nil
        end
      end
      hsprm.delete :destroy_engage  # no effect?

      # Obtains Date and DateTime
      #
      # Because the Web form has a precision of only a second, a sub-second difference,
      # or maybe any differelce less than 2 seconds, is ignored.
      %w(release_date ins_release_date ins_at).each do |ek|
        ev = helpers.get_date_time_from_params(hsprm, ek) || next
        next if ('ins_at' == ek) && @harami1129.send(ek) && (@harami1129.send(ek) - ev).abs < 2
        @harami1129.send ek+'=', ev
      end

      if hsprm.key?(:human_check) && helpers.get_bool_from_params(hsprm[:human_check])
        @harami1129.checked_at = Time.now
      elsif @harami1129.checked_at && hsprm.key?(:human_uncheck) && helpers.get_bool_from_params(hsprm[:human_uncheck]) # In fact, this option is not provided on the web interface if !@harami1129.checked_at (but just to play safe).
        # 1 second before orig_modified_at or whatever significant.
        @harami1129.checked_at = %i(orig_modified_at last_downloaded_at updated_at).map{|i| @harami1129.send(i)}.compact.sort.first - 1
      end

      allcs = INDEX_COLUMNS.map(&:to_s)
      hsprm.each_pair do |ek, ev|
        # not_music would be set either true/false (from the original nil)
        next if !allcs.include? ek
        next if %w(destroy_engage human_check human_uncheck).include? ek
        if ek == 'note'
        end
        next if ev.respond_to?(:empty?) && ev.empty? && @harami1129.send(ek).nil?
        if /\Ains_/ =~ ek
          @harami1129.send ek+'=', any_zenkaku_to_ascii(ev) # defined in ModuleCommon
        else
          @harami1129.send ek+'=', ev
        end
      end
    end

    # Insert one entry to DB.  Exception if fails.
    #
    # @param entry [Hash] The data to insert
    # @param entry [Nokogiri] HTML table row object. Used for Error message.
    # @return [ActiveRecord, Exception] nil if failed. Otherwise {Harami1129} instance (you need to "reload")
    def insert_one_db!(entry, tr, debug: false)

      #existings = Harami1129.where(link_time: entry[:link_time], link_root: entry[:link_root])
      #harami = ((existings.size > 0) ? existings[0] : Harami1129.new)
      #entry.each_pair do |ek, ev|
      #  harami.send(ek.to_s+'=', ev)
      #end

      begin
        harami = Harami1129.insert_a_downloaded!(**entry)
        #harami.save!
      rescue ActiveRecord::RecordInvalid => err
        #new_or_upd = (harami.id ? "create a" : "update an existing (ID=#{harami.id})")
        msg = sprintf "Failed to update/create a record (%s) from harami1129 on DB with a message: %s", tr.text, err.message
        logger.warn msg
        @last_err = msg
        return nil
      end

      harami
    end

end
