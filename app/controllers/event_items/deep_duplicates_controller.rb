# coding: utf-8

class EventItems::DeepDuplicatesController < ApplicationController
  # Controllers can be accessed only by authenticated users in default, but authorization needs a specific approach below.

  PREFIX_MACHINE_TITLE_DUPLICATE = "copy"  # followed by (potentially a number and) a hyphen "-", as in EventItem default (EventItem.get_unique_title)

  # Creates a dup of EventItem, where
  #   * machine_title is (has to be) unique
  #   * weight is nil
  #   * All the other direct parameters are same, except for the primary ID and timestamps.
  #   * All the associated ArtistMusicPlay-s are copied and inherited (obviously except for *event_item_id*)
  #   * All the associated HaramiVidEventItemAssoc-s are copied and inherited (because it is easier to destroy the association later if the user wants than to re-create an association)
  #
  # In the end, redirects back to HaramiVid-show of the given @harami_vid
  def create
    set_event_item  # set @event_item_ref and @harami_vid
    authorize! __method__, @harami_vid

    evit = @event_item_ref.dup

    evit.machine_title = _get_unique_copied_machine_title
      # => e.g., "copy-unk_Event_in_Tocho(...)", "copy2-Hitori-20240101_Tocho_<_Single-shotStreetpianoPlaying"

    evit.weight = nil  # Only weight

    @event_item_ref.harami_vids.each do |ehv|
      evit.harami_vids << ehv
    end
    @event_item_ref.artist_music_plays.each do |eamp|
      amp_new = eamp.dup
      amp_new.event_item = nil
      evit.artist_music_plays << amp_new
    end

    back_path = harami_vid_path(@harami_vid)
    result = def_respond_to_format(evit, redirected_path: back_path, render_err_path: back_path, force_redirect: true)      # defined in application_controller.rb
  end

  private

    # set @event_item_ref and @harami_vid from a given URL parameter
    def set_event_item
      @event_item_ref = nil
      safe_params = params.require(:event_item).require(:deep_duplicates_controller).permit(
        :event_item_id, :harami_vid_id)

      @event_item_ref = EventItem.find safe_params[:event_item_id]
      @harami_vid     = HaramiVid.find safe_params[:harami_vid_id]
      raise "Strange..." if !@event_item_ref.harami_vids.where("harami_vids.id = ?", @harami_vid.id).exists?  # sanity check
    end

    # @example
    #    _get_unique_copied_machine_title
    #      # => e.g., "copy-unk_Event_in_Tocho(...)", "copy2-Hitori-20240101_Tocho_<_Single-shotStreetpianoPlaying"
    #
    # @return [String] machine_title guaranteed to be unique.
    def _get_unique_copied_machine_title
      mtit = @event_item_ref.machine_title.dup
      EventItem::UNKNOWN_TITLE_PREFIXES.values.each do |prefix|
        # In case of "Unknown", the word is replaced.
        # prefix is like "UnknownEventItem_" (foe "en")
        mat = /(.*)([_\-]+)\z/.match prefix
        root = Regexp.quote(mat ? mat[0] : prefix)
        separator_regex = (mat ? Regexp.quote(mat[1]) : "")
        mtit.sub!(/\A#{root}#{separator_regex}/, "unk"+(mat ? mat[1].tr_s("_\-", "_\-") : "_"))
      end

      EventItem.get_unique_title(PREFIX_MACHINE_TITLE_DUPLICATE, postfix: mtit)
    end

end
