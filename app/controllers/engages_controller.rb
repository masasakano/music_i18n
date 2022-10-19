class EngagesController < ApplicationController
  # "edit" and "update" are eliminated for the sake of simplicity;
  # these actions are handled by {EngageMultiHowsController}
  before_action :set_engage, only: %i( new )
  before_action :authorize_roughly, only: %i( index, new, create, destroy ) # show is accepted public

  # GET /engages or /engages.json
  def index
    @engages = Engage.all
  end

  # GET /engages/1 or /engages/1.json
  def show
    @engage = Engage.find(params[:id])
  end

  # GET /engages/new
  def new
  end

  # POST /engages or /engages.json
  def create
    set_engage  # @engage is set, though it is invalid with no engage_how or Artist
    params.permit!
    # hsbase = engage_params  # For some reason this does not permit engage_how...
    hsbase = params[:engage]

    # Find an Artist
    artist =
      if !hsbase[:artist_id].blank?
        Artist.find(hsbase[:artist_id])
      elsif hsbase[:artist_name].blank?
        nil
      else
        Artist.find_by_name(hsbase[:artist_name])
      end
    artist = (hsbase[:artist_id] ? Artist.find(hsbase[:artist_id]) : Artist.find_by_name(hsbase[:artist_name]))
    @engage.errors.add :artist_name, "with the name #{hsbase[:artist_name].inspect} does not exist." if !artist

    # Multiple EngageHow IDs
    specified_engage_how_ids = (hsbase[:engage_how].blank? ? [] : hsbase[:engage_how].map{|i| i.blank? ? nil : i}.compact)
    @engage.errors.add :engage_how, "is unspecified." if specified_engage_how_ids.empty?

    if @engage.errors.size > 0
      respond_to do |format|
        format.html { render :new }
      end
      return
    end

    hsbase = hsbase.slice(*(%i(music_id year contribution note)))

    begin
      ActiveRecord::Base.transaction do
        specified_engage_how_ids.each do |ehid|
          @engage = Engage.new(**(hsbase.merge({engage_how_id: ehid, artist: artist})))
          @engage.save!
        end
      end
    rescue => err
      msg = sprintf "(%s#%s) Engage for Music(ID=%s) failed to be updated by User(ID=%s) with error: %s", self.class.name, __method__, current_user.id, @engage.music_id, err.message
      logger.debug msg
      return respond_to do |format|
        format.html { render :new, music_id: @engage.music_id }  # music_id (as an argument for render) is probably redundant
        format.json { render json: @engage.errors, status: :unprocessable_entity }
      end
    end

    respond_to do |format|
      msg = sprintf 'Engage for Artist=%s (Engaged in %d) was successfully created.', artist.title.inspect, @engage.year
      format.html { redirect_to @engage.music, success: msg } # "success" defined in /app/controllers/application_controller.rb
      format.json { render :show, status: :created, location: @engage }
    end
  end

  # DELETE /engages/1 or /engages/1.json
  def destroy
    @engage = Engage.find(params[:id])
    @engage.destroy
    respond_to do |format|
      format.html { redirect_to engages_url, success: "Engage was successfully destroyed." } # "success" defined in /app/controllers/application_controller.rb
      format.json { head :no_content }
    end
  end

  private
    # authorize based on only the model class
    def authorize_roughly
      authorize! action_name.to_sym, Engage
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_engage
      # @engage = Engage.find(params[:id])

      #params.require([:artist_id, :music_id]) # when called second time after create! fails, the params is params[:engage][:artist_id]
      params.permit!
      params[:engage].permit! if params[:engage]
      hskwd = {}
      %i(music_id artist_id engage_how year contribution note).each do |ek|
        hskwd[ek] = params[ek] if params[ek]
        hskwd[ek] = params[:engage][ek] if params[:engage] && params[:engage][ek]
      end

      # If the given parameter is nil (which should not happen if accessed
      # from the web interface), the parameter would be unchanged,
      # and if empty?, the existing value in the DB will be reset to nil.
      hskwd.select!{|k,v| !v.nil?}
      hskwd = hskwd.map{|k,v| [k, (v.blank? ? nil : v)]}.to_h

      @music  = Music.find  hskwd[:music_id]
      hskwd[:year] ||= @music.year

      @engage  = Engage.new(**(hskwd.slice(*(%i(music_id year contribution note)))))
    end

    # Only allow a list of trusted parameters through. create only (NOT update)
    def engage_params
      params.permit!
      params.require(:engage).permit(:contribution, :year, :artist_name, :artist_id, :engage_how, :music_id, :note)
      # For some reason, only :engage_how is NOT permitted...
    end
end
