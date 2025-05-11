class DiagnoseController < ApplicationController
  def index
    authorize! :index, DiagnoseController
    methods2examine = {
      HaramiVid: :_get_problematic_harami_vids,
      Music:     :_get_problematic_musics,
      Artist:    :_get_problematic_artists,
    }.with_indifferent_access

    @problems = {}.with_indifferent_access
    @problems_keys = {}.with_indifferent_access

    methods2examine.each_pair do |modelsys, method2call| 
      wrongs = send(method2call)
      @problems_keys[modelsys] = wrongs.keys
      @problems[modelsys]     = _build_ret_hash(wrongs)
    end
  end

  private

    ## TODO:
    # @todo 
    #   inconsistent Place with EventItems
    def _get_problematic_harami_vids
      wrongs = {}.with_indifferent_access
      %w(uri release_date channel_id).each do |eatt|  # Most serious inconsistencies
        _set_all_no_value_for_attr(wrongs, HaramiVid, eatt)  # => "no_release_date", "no_place_id" => [ActiveRocord, ...]
      end
      %w(event_items musics).each do |eatt|  # Fairly serious inconsistencies
        _set_all_no_association_for_attr(wrongs, HaramiVid, eatt)  # => "no_event_items" => [ActiveRocord, ...]
      end

      wrongs["inconsistent_n_musics"] = HaramiVid.all.find_all{|record| record.n_inconsistent_musics > 0}

      %w(duration place_id).each do |eatt|  # Less serious inconsistencies
        _set_all_no_value_for_attr(wrongs, HaramiVid, eatt)  # => "no_release_date", "no_place_id" => [ActiveRocord, ...]
      end
      wrongs
    end

    ## TODO:
    # @todo 
    def _get_problematic_musics
      wrongs = {}.with_indifferent_access
      %w(genre_id).each do |eatt|
        _set_all_no_value_for_attr(wrongs, Music, eatt)
      end
      %w(engages harami_vids).each do |eatt|  # Fairly serious inconsistencies
        _set_all_no_association_for_attr(wrongs, Music, eatt)  # => "no_event_items" => [ActiveRocord, ...]
      end
      %w(year place_id).each do |eatt|
        _set_all_no_value_for_attr(wrongs, Music, eatt)
      end
      wrongs
    end

    ## TODO:
    # @todo 
    #    Those with neither engages nor ArtistMusicPlays
    def _get_problematic_artists
      wrongs = {}.with_indifferent_access
      %w(sex_id place_id).each do |eatt|
        _set_all_no_value_for_attr(wrongs, Artist, eatt)
      end
      wrongs
    end

    def _set_all_no_value_for_attr(wrongs, model, att)
      wrongs["no_"+att] = model.where(att => nil)  # wrongs["no_uri"] etc
    end

    def _set_all_no_association_for_attr(wrongs, model, association, att=association)
      wrongs["no_"+association] = model.left_joins(association.to_sym).where(att.pluralize+".id" => nil)  # wrongs["no_musics"] etc
    end

    # @return [Hash] ActiveRecord => Array<Keywords> where keywords are like "no_place_id"
    def _build_ret_hash(wrongs)
      hsret = {}.with_indifferent_access
      artmp = wrongs.values.sum([]).uniq.map{ |erec|  # No sort, but in the given order, so no_uri comes first etc, which should be in the order of seriousness.
        hsret[erec] = []
        wrongs.each_pair do |reason, records|
          if records.include? erec
            hsret[erec] << reason
          end
        end
      }
      hsret
    end
end
