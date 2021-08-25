# coding: utf-8

# Controller to inject data from harami1129s table to our tables, including
# artists and musics and HaramiVid and HaramiVidMusicAssoc
#
class Harami1129s::InjectFromHarami1129sController < ApplicationController
  include ModuleCommon  # zenkaku_to_ascii

  # before_action :set_harami1129, only: [:create]
  load_and_authorize_resource

  FORM_SUBMIT_NAME = '???????'

  # GET /inject_from_harami1129s
  # GET /inject_from_harami1129s.json
  def create
    create_or_update_all
  end

  protected

  def create_or_update_all
    # => ["id", "singer", "song", "release_date", "title", "link_root", "link_time", "ins_singer", "ins_song", "ins_release_date", "ins_title", "ins_link_root", "ins_link_time", "ins_at", "note", "created_at", "updated_at", "id_remote", "last_downloaded_at"]


    inject_from_harami1129_params(default: false)
    if [FORM_SUBMIT_NAME, 'debug', 'max_entries_fetch'].any?{|i| params.keys.include? i}
      inject_from_harami1129(max_entries_fetch: params[:max_entries_fetch], debug: !!params[:debug])
    end
    @harami1129s = Harami1129.all

    n_updated = 0
    @harami1129s.each do |row|
      inject_local_tables_one(row)
      n_updated += 1 if row.updated_at_changed?
    end
    msg = sprintf "(%s) %d/%d rows in Harami1129 are updated for ins_*.", __method__, n_updated, Harami1129.count
    logger.info msg
  end

#brails g migration add_not_music_to_harami1129 not_music:bool
  ########
  ########
  # is_music in Harami1129
  ########
  ########

  #
  #
  # == Algorithm
  #
  # The {Translation} for each Model is tightly associated to the model; therefore {Translation}
  # must be created (or updated, if required) simultaneously in create of any instance.
  # The other associations are, except for {Harami1129}'s belongs_to {HaramiVid},
  # many to many.  Therefore, in create (rather than update), each instance can be created,
  # ignoring the potential associations (n.b., {HaramiVid} has_many {Harami1129} and NOT
  # belongs_to, and hence even {HaramiVid} can be created independently of the ohters).
  # Then the intermediate records ({Engage} and {HaramiVidMusicAssoc}) are created afterwards.
  #
  # In short,
  #
  # (1) {HaramiVid}: URI-related, date, place
  # (2) {Music}: Title ({Translation})
  # (3) {Artist}: Title ({Translation})
  # (3) {EngageHow}: 
  # (5) {HaramiVidMusicAssocs}: (association)
  # (6) {Engage}: (Association; unkown)
  #
  # There are 2 cases:
  #
  # (1) If harami_vid_id in {Harami1129} is significant, 
  # (2) If not, {HaramiVid} is searched for, whether entirely or partially.
  #
  # Whichever, the next procedures are similar.
  #
  # (1) Matching {HaramiVid} record, if exists, will be updated, where it is nil (none of existing significant records is updated).  If none (case (2)), craeted.
  # (2) Matching {Artist} is searched for (already associated if {HaramiVid} exists).  If none (for new {HaramiVid}; for updating, it should not be the case), created. If nil (unlikely), updated.
  # (3) Matching {Music} is searched for (already associated if {HaramiVid} exists).  If none (for new {HaramiVid}; for updating, it should not be the case), created, along with corresponding {Engage} and {HaramiVidMusicAssoc}.
  # (4) Matching {HaramiVidMusicAssoc} is searched for. It should exist at this stage. If time is nil, updated.
  #
  # Note there is a real possibility that even if Procedure (1) does nothing,
  # one or more of later Procedures may do something.  {Harami1129} has separate rows
  # for separate musics in a single video (URI), whereas {HaramiVid} has one row
  # per video.
  #
  # For potential update, {Artist} should be searched for before {Music} because
  # multiple {Music}-s with a common title (e.g., "M") may exist, whereas the same {Artist}-s
  # are less likely.
  #
  # If one of them fails, it simply stops there with no rollback.
  # No following model-records will be created/updated.
  #
  # == Cases
  #
  # (1) Fresh case
  #     No HaramiVid, no Music, no Artist, no HaramiVidMusicAssoc
  # (2) New HaramiVid with an existing Music
  #     Music must be identified from the title, singer, etc.
  # (3) Existing but unrelated (no insertable) HaramiVid with an existing Music
  #     HaramiVid must be identified from the title, url, etc.
  # (4) Update (attempt). Existing HaramiVid with an existing Music
  #
  # @param harami1129 [Harami1129] model
  def inject_local_tables_one(harami1129)
    # crows: Hash (key: model-name in snake_case) of Model-record objects to which records are injected/inserted.
    crows = Harami1129s::InjectFromHarami1129::MAPPING_HARAMI1129.map{|k, v| [k, nil]}.to_h

    model_snake = 'harami_vid'
    crows[model_snake] = inject_to_a_table(model_snake, harami1129, crows){ |model_class|
      harami1129.harami_vid
    }

    # Update the Harami1129 record to add an association:
    harami1129.harami_vid ||= crows[model_snake]

    model_snake = 'artist'
    crows[model_snake] = inject_to_a_table(model_snake, harami1129, crows){ |model_class|
      crows['harami_vid'].artists
    }
    return crows if !crows[model_snake]  # No singer/artist is defined.

    model_snake = 'music'
    crows[model_snake] = inject_to_a_table(model_snake, harami1129, crows){ |model_class|
      crows['harami_vid'].musics
    }
    return crows if !crows[model_snake]  # No song/music is defined.

    # Inject to Engage
    if !crows['music'].artists.include? crows['artist']
      crows['music'].artists << crows['artist']
    end

    # Inject to HaramiVidMusicAssoc
    model_snake = 'harami_vid_music_assoc'
    crows[model_snake] = inject_to_a_table(model_snake, harami1129, crows){ |model_class|
      crows['harami_vid'].harami_vid_music_assocs.where(music: crows['music'])
    }

    crows

    ## Inject to musics
    #model_snake = 'music'
    #model_class = model_snake.camelize.constantize
    #ar = crows['harami_vid'].musics
    #crows[model_snake] = ar.first
    #if (ar.count rescue ar.size) > 1
    #  logger.warn "Ambiguous musics ID=#{ar.map{|i| i.id}.inspect} for a given Harami1129(id=#{harami1129.id}, singer=#{harami1129.ins_song.inspect}=>#{cells_inject.ins_song.inspect})"
    #end
    #crows[model_snake] = get_destination_row(row_cands_def, model_class, harami1129, cells_inject, crows['artist']) if !crows[model_snake] # An "artist" is given as a constraint.
    #update_or_create_row(crows[model_snake])

    ## Inject to Engage
    #if !crows['music'].artists.include? crows['artist']
    #  crows['music'].artists << crows['artist']
    #end

    ## Inject to HaramiVidMusicAssoc
    #model_snake = 'harami_vid_music_assoc'
    #model_class = model_snake.camelize.constantize
    #records = crows['harami_vid'].harami_vid_music_assocs.where(music: crows['music'])
    #crows[model_snake] = 
    #  if records.count == 0
    #    crows['harami_vid'].harami_vid_music_assocs << crows['music']
    #  else
    #    records.first
    #  end
    #update_or_create_row(crows[model_snake])
  end


  # Inject from a Harami1129 record to a given model, which is returned
  #
  # A block must be provided which defines how the injection is performed.
  #
  # @param model_snake [String] like "harami_vid"
  # @return [BaseWithTranslation, NilClass]
  # @yield from ModelClass, returns the candidate Array to update
  def inject_to_a_table(model_snake, harami1129, crows)
    model_class = model_snake.camelize.constantize

    # Gets an already-defined existing record
    ar = yield(model_class)  # ar = crows['harami_vid'].artists
    retrow = ar.first
    if (ar.count rescue ar.size) > 1
      plur = model_snake.pluralize
      errmsg = "Ambiguous %s ID=%s for a given Harami1129(id=%d, Song=%d), before-insert: %s", plur, ar.map{|i| i.id}.inspect, harami1129.id, harami1129.ins_song.inspect, cells2inject(harami1129)
      logger.warn errmsg
    else
      # If no exiting record is defined, searches for an existing record based on hsmain and translation.
      # If not found, a new record is returned.
      retrow = get_destination_row(harami1129, model_class, crows)
    end

    if !retrow  # This should never happen.
      msg = "Failed to get both updated and new record for some reason for %s for a given Harami1129(id=%d, Song=%d), before-insert: %s", plur, harami1129.id, harami1129.ins_song.inspect, cells2inject(harami1129)
      logger.error msg
      raise msg
    end

    # Gets the parameters to update (basically, those that are nil in the existing record)
    hsmain = get_hsmain_to_update(harami1129, model_class, {model_snake => retrow}.merge(crows), model_snake)

    # Save or updates.  If adding a Translaiton faile, rollbacks.
    begin
      ActiveRecord::Base.transaction do
        retrow.updates!(**hsmain)
        if retrow.translations.count == 0
          # Translations created, NOT updated (n.b., to update, use with_updated_translations())
          hstrans = hash_for_trans(harami1129, model_class)
          retrow.with_translations(**hstrans)
        end
        return retrow
      end
    rescue
      msgtail = (hstrans ? " with Translation=#{hstrans.inspect}" : "")
      logger.error "Create/Update failed for #{model_class.name} with hsmain=#{hsmain.inspect}"+msgtail
      raise
    end
  end


  # Returns the destination model instance to which the record is either
  # newly injected or updated (if need be).
  #
  #
  # @return [ApplicationRecord]
  # @yield should return the model-record candidate based on the association.
  def get_destination_row(harami1129, model_class, crows)
    # Translation-based guess of the existing model record.
    # It uses HaramiVid title as well; therefore this should agree with
    # row_cands_def
    hstrans = hash_for_trans(harami1129, model_class)
    hsmain = get_hs_to_update(harami1129, model_class, crows, ignore_double_us: true)

    cands = model_class.select_by_translations(hsmain, **hstrans)

    n_cands = cands.count 
    if n_cands > 1
      msg = sprintf "Multiple (n=%d) rows (ID=%s) found from Translations for %s corresponding to Harami1129(id=%d, ins_title=%s)", n_cands, cands.pluck(:id).inspect, model_class.name, harami1129.id, harami1129.ins_title
      logger.warn msg
    end
    return cands.first if n_cands > 0

    model_class.new(**hsmain)

    #if nrows == 0
    #  # Case(1)(2)(3) if HaramiVid; Fresh or new HaramiVid with an existing association, or HaramiVid with existing but yet-unrecognised one to be updated.
    #  if n_from_trans > 1
    #    msg = sprintf "Multiple (n=%d) rows (ID=%s) found from Translations for %s corresponding to Harami1129(id=%d, ins_title=%s)", n_from_trans, row_cands_from_trans.pluck(:id).inspect, model_class.name, harami1129.id, harami1129.ins_title
    #    logger.warn msg
    #  end

    #  # This should be nil; if non-nil, it means the association has not 
    #  # been correctly set for some reason.
    #  row_cand = row_cands_from_trans.first
    #else
    #  # Case(4): HaramiVid exists, and we are updating it.
    #  if n_from_trans == 0
    #    # This happpens when one of the records (be it our importing tables or Harami1129) has changed.
    #    msg = sprintf "One of the records in (ins_* in Harami1129, or HaramiVid, Music, Artist) must have changed since the last import. %s(id=%s), corresponding to Harami1129(id=%d, ins_title=%s)", model_class.name, cands.first.id, harami1129.id, harami1129.ins_title
    #    logger.info msg
    #    row_cand = cands.first
    #  else
    #    cands = row_cands_def.select{|row| row_cands_from_trans.include? row}
    #    if cands.size == 1
    #      # Perfect; association-based and translation-based guesses agree.
    #      row_cand = cands.first

    #    elsif cands.size == 0
    #      # This is weird. There is a different HaramiVid from association-based
    #      # identification that matches the record based on Translation.
    #      # It should never happen, and even if it does, it is extremely unlikely.
    #      # association-based guess has a priority.
    #      row_cand = row_cands_def.first

    #      ids = (row_cands_def.pluck(:id) rescue row_cands_def.map{|i| i.id})
    #      msg = sprintf "Inconsistent rows between association-based guess (ID=%d) and those (ID=%s) from Translations for %s corresponding to Harami1129(id=%d, ins_title=%s)", ids.inspect, row_cands_from_trans.pluck(:id).inspect, model_class.name, harami1129.id, harami1129.ins_title
    #      logger.warn msg

    #    else  # if cands.size > 1
    #      # Multiple association-based guesses, agreeing with Translation-based.
    #      # Maybe HaramiVid somehow contains very similar multiple records?
    #      row_cand = cands.first

    #      msg = sprintf "Ambiguous: Multiple (n=%d) rows (ID=%s) found from Translations for %s corresponding to Harami1129(id=%d, ins_title=%s)", n_from_trans, row_cands_from_trans.pluck(:id).inspect, model_class.name, harami1129.id, harami1129.ins_title
    #      logger.warn msg
    #    end
    #  end
    #end
    #  
    ## For new_record, row_cand should be nil.
    #row_cand ? row_cand : model_class.new
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_inject_from_harami1129
      @harami1129 = Harami1129.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def inject_from_harami1129_params(default: true)
      if default
        params.require(:harami1129).permit(*INDEX_COLUMNS)
      else
        if params[:harami1129s_grid]
          ActionController::Parameters.permit_all_parameters = true
          # params.permit(:commit, harami1129s_grid: {})
          # params[:harami1129s_grid].permit(*DATA_GRID_COLUMN_ARGS, **DATA_GRID_COLUMN_OPTS)
        else
          params.permit(*(INDEX_COLUMNS+INJECT_FROM_HARAMI1129_COLUMNS))
        end
      end
    end

end
