# Controllers to edit/delete/add a set of existing {Engage}s
# for a pair of {Artist} and {Music} with multiple {EngageHow}s
class EngageMultiHowsController < ApplicationController
  include ModuleCommon # for split_hash_with_keys

  before_action :set_engages, only: %i( index new )  # Unusual, but for index only.
  load_and_authorize_resource :engage

  # GET parameters of {Artist} and {Music} IDs are mandatory.
  def index
  end

  def show
    edit
  end

  def edit
    engage = Engage.find(params[:id])
    # redirect_to engage_multi_hows_path(request.parameters.merge({artist_id: engage.artist_id, music_id: engage.music_id}))
    redirect_to engage_multi_hows_path(artist_id: engage.artist_id, music_id: engage.music_id)
  end

  def create
    # Parameters: {"authenticity_token"=>"[FILTERED]", "engage"=>{"year_20"=>"", "contribution_20"=>"", "note_20"=>"", "to_destroy_20"=>"true", "engage_how"=>["", "9", "7"], "year"=>"", "contribution"=>"", "note"=>"", "artist_id"=>"3", "music_id"=>"10"}, "commit"=>"Submit"}
    # NOTE: if the checkbox is not checked, the key "to_destroy_20" does NOT exist.
    params.require([:engage])
    params.permit!

    to_destroy = 'to_destroy'
    raise 'Contac the code developer' if !Engage.method_defined?(to_destroy.to_sym)

    # Hash newhs for those for to-be-added Engages, and resths for existing Engages
    newhs, resths = split_hash_with_keys(params[:engage], %w(artist_id music_id engage_how year contribution note))
    hs_existent = {}
    resths.each_pair do |k,v|
      next if (/^(year|contribution|note|#{Regexp.quote to_destroy})_(\d+)/ !~ k)
      eid = $2.to_i
      hs_existent[eid] = {} if !hs_existent.key? eid
      hs_existent[eid][$1] = 
        if $1 == to_destroy
          helpers.get_bool_from_params(v)
        else
          (v.blank? ? nil : v)  # If blank, replaced with nil.
        end
    end

    n_updated = 0
    n_destroyed = 0
    n_new = 0
    begin
      ActiveRecord::Base.transaction do
        # Creates (multiple) Engages if specified
        hs, hsprm = split_hash_with_keys(newhs, ['engage_how'])
        hsprm.select!{|k,v| !v.blank?}
        specified_engage_hows = hs['engage_how'].map{|i| i.blank? ? nil : i}.compact
        specified_engage_hows.each do |engage_how_id|
          Engage.create! hsprm.merge({engage_how_id: engage_how_id})
          n_new += 1
        end

        # sanity (security) check
        engages = {}
        hs_existent.each_pair do |eid, ea_prms|
          engages[eid] = engage = Engage.find(eid)
          next if !engage # This could happen if Engage is destroyed independently and simultaneously by someone unrelated.
          if engage.artist_id != newhs['artist_id'].to_i || engage.music_id !=newhs['music_id'].to_i
            # Should never happen except for malicious attacks.
            raise "Unrelated Engage is specified! ID=#{engage.id}"
          end
        end

        # destroys some existing records (Note new ones, if any, have been already created).
        ids_to_destroy = hs_existent.map{|ek, eh| eh.key?(to_destroy) && eh[to_destroy] && ek || nil}.compact
        n_destroyed = destroy_engages(engages, ids_to_destroy, newhs)

        # Removes the to_destroy key from the Hash (to be used in update!)
        hs_existent.each_value{|eh|
          eh.delete(to_destroy) if eh.key?(to_destroy)
        }

        # edits existing records
        hs_existent.each_pair do |eid, ea_prms|
          engage = engages[eid] || next  # "next" if it is destroyed by someone else simultaneously.
          next if ids_to_destroy.include? eid  # already destroyed.

          engage.update!(ea_prms)
          if engage.saved_changes?
            n_updated += 1
            msg = sprintf "(%s#%s) Engage(ID=%s) updated by User(ID=%s): saved_changes=%s", self.class.name, __method__, eid, current_user.id, engage.saved_changes.inspect
            logger.debug msg
          end
        end
      end
    rescue => err
      ## Transaction or processing failed.
      msg = sprintf "(%s#%s) Engages failed to be updated by User(ID=%s) with error: %s", self.class.name, __method__, current_user.id, err.message
      logger.debug msg
      if /Unrelated Engage/ =~ msg
        logger.error msg
        raise
      end
      set_engages if !defined?(@engage) || !defined?(@engages)  # to set @engage etc
      @engage.errors.add :base, err.message
    end

    # Note @engage always exists because of load_and_authorize_resource
    # though it is nil unless explicitly reset by set_engages(), which
    # is called when encountering an error.
    if @engage && @engage.errors.present?
      respond_to do |format|
        format.html { render :index }  # A bit unusual, but render :index
        format.json { render json: @engage.errors, status: :unprocessable_entity }
      end
    else
      respond_to do |format|
        msg = sprintf "Updated %d, destroyed %d, and created %d Engages successfully.", n_updated, n_destroyed, n_new
        format.html { redirect_to engage_multi_hows_path(artist_id: newhs['artist_id'], music_id: newhs['music_id']), notice: msg }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_engages
      #params.require([:artist_id, :music_id]) # when called second time after create! fails, the params is params[:engage][:artist_id]
      params.permit!
      hskwd = {}
      %i(engage_how_id year contribution note).each do |ek|
        hskwd[ek] = params[ek] if params[ek]
      end

      @music  = Music.find( params[:music_id]  || params[:engage][:music_id])
      @artist = Artist.find(params[:artist_id] || params[:engage][:artist_id])
      @engages = Engage.where(artist: @artist, music: @music).joins(:engage_how).order('engage_hows.weight')
      @engage  = Engage.new(  artist: @artist, music: @music, year: @music.year, **hskwd)
      @engage_others = (@engages.exists? ? @engages.first : @engage).with_the_other_artists
    end

    ## Only allow a list of trusted parameters through. create only (NOT update)
    #def engage_params
    #  params.require(:engage).permit(:contribution, :year, :artist_id, :engage_how_id, :music_id, :note)
    #end

    # Destory specified Engages, providing it satisfies certain conditions;
    # i.e., either dependent Harami1129s do not exist or there are alternative
    # Engages that can be assigned to those dependent Harami1129s.
    #
    # @param engages [Hash] id => Engage for the same Artist and Music
    # @param ids_to_destroy [Array] of id-s to destroy
    # @param newhs [Hash] taken from params, containing artist_id and music_id (String or Integer)
    # @return [Integer] Number of the destroyed records.
    def destroy_engages(engages, ids_to_destroy, newhs)
      return 0 if ids_to_destroy.empty?

      all_music_engages = Engage.where(music: newhs['music_id'])  # Same Music, any Artists
      all_this_engages  = all_music_engages.where(artist_id: newhs['artist_id']) # Same Music&Artist
      harami1129s = Harami1129.joins(:engage).where('engage_id IN (?)', all_this_engages.pluck(:id)).distinct
      if harami1129s.count > 0 && ids_to_destroy.size >= all_music_engages.count
        set_engages if !defined?(@engage) || !defined?(@engages)  # to set @engage etc
        msg = 'Cannot destroy all Engages about this Music when a dependent Harami1129 exists.'
        @engage.errors.add :to_destroy, msg
        raise ActiveRecord::Rollback, 'Rollback because: '+msg
warn "ERROR:This should be never executed.... rollback"
      end

      # Build a Relation to get a new Engage ID to assign to the existing Harami1129s
      all_this_ids = all_this_engages.pluck :id
      if all_this_ids.all?{|i| ids_to_destroy.include? i}
        # Harami1129#engage_id will be assigned to an Enage with a different Artist
        rela = all_music_engages.where.not(artist_id: newhs['artist_id'])
      else
        # Harami1129#engage_id will be assigned to an Enage with the same Artist with a different EngageHow
        rela = all_this_engages.where.not('engages.id IN (?)', ids_to_destroy)
      end

      # Update Harami1129#engage_id for *all* related Harami1129s.
      # Note that even if the related Engage for a Harami1129 is not destroyed,
      # if one of the Engages is destroyed, the Harami1129#engage_id may be
      # updated. For example,
      #
      #   a_harami1129.engage  # => (AI, Story, How(Composer))
      #   engage(AI, Story, How(Unknown)).destroy
      #   a_harami1129.engage  # => (AI, Story, How(Singer_Original))
      #
      # This should not matter because the whole purpose of a Harami1129 having
      # a related Engage is just a convenient way to point both an Artist and Music
      # and therefore EngageHow (or year) is irrelevant.
      harami1129s.each do |h1129|
        engage = rela.joins(:engage_how).order('engage_hows.weight').first
        raise 'Contact the code developer. engage should never be nil here' if !engage
        h1129.engage = engage
        h1129.save!
      end

      n_destroyed = 0
      # Destroy Engages
      ids_to_destroy.each do |idd|
        if engages[idd]
          engages[idd].destroy
          n_destroyed += 1
        end
      end
      return n_destroyed
    end
end

