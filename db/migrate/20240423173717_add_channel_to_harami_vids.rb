# coding: utf-8
class AddChannelToHaramiVids < ActiveRecord::Migration[7.0]
  def change
    # HaramiVid should have Channel - but migration with "null: false" would fail and so it is allowed to be nil at the moment.
    # A Channel with children cannot be destroyed easily.
    add_reference :harami_vids, :channel, null: true, foreign_key: true

    #### The following is basically moved to /db/seeds.rb
    #### As far as DB is concerned, it works with HaramiVid with null Channel
    #### (if they may cause trouble in the operation of the app).
    #### See the previous version (i.e., 5ee5458) for the code,
    #### which failed for a fresh DB because it relied on the presence
    #### of some records like ChannelType.unknown.
    #reversible do |direction|
    #  direction.up do
    #    arret = _create_basic_channels
    #    puts "-- Created #{arret.join(' and ')}" if !arret.empty?
    #  end
    #end
  end
end
