class ChannelOwners::CreateWithArtistsController < ApplicationController
  # creates ChannelOwner (Although the method name is "new", this is a "new" method in Creates-Controller)
  def new
    set_artist  # set @artist
    authorize! :update, @artist
    authorize! __method__, ChannelOwner

    @channel_owner = ChannelOwner.new(artist: @artist)
    @channel_owner.themselves = true  # essential.
    @channel_owner.set_unsaved_translations_from_artist  # set @unsaved_translations referring to the Artist

    result = def_respond_to_format(@channel_owner, created_updated: :created, back_html: "&ldquo;ChannelOwner&rdquo; page") # defined in application_controller.rb

    # Adjusts each Translation's update_user and updated_at if there is an equivalent user.
    # These are not critical and so not included in DB-Transaction in the save above.
    if result
      @channel_owner.update_user_for_equivalent_artist
    end
  end

  private
    # set @artist from a given URL parameter
    def set_artist
      @artist = nil
      artist_id = params.require(:channel_owner).permit(:artist_id)[:artist_id]  # => channel_owner[artist_id]=123
      return if artist_id.blank? 
      @artist = Artist.find(artist_id)
    end
end
