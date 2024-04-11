class RenameTableEngageEventItemHowToPlayRole < ActiveRecord::Migration[7.0]
  class Translation < ApplicationRecord
    # Defines the class to make sure table "translations" are handled, whatever the current model name is.
  end
  def _calc_trans_counts
    [Translation.count,
     Translation.where(translatable_type: "EngageEventItemHow").count,
     Translation.where(translatable_type: "PlayRole").count]
  end
  def change
    rename_table("engage_event_item_hows", "play_roles")  # reversible change.
    change_table_comment(:play_roles, from: "How an Engage-EventItem is associated.",
                                      to: "Role Artist plays in playing Music in EventItem for ArtistMusicPlay")
    flag_debug = false  ## If this is true, migration always stops.
    reversible do |migr|
      migr.up   {
        puts "DEBUG(migration#{File.basename(__FILE__).split('_')[0]}): Tra-counts(Be4)(all,Eng(some),Pla(0))=#{_calc_trans_counts.inspect}" if flag_debug
        Translation.where(translatable_type: "EngageEventItemHow").update_all(translatable_type: "PlayRole")
        puts "DEBUG(migration#{File.basename(__FILE__).split('_')[0]}): Tra-counts(Aft)(all,Eng(0),Pla(some))=#{_calc_trans_counts.inspect}" if flag_debug
        raise "DEBUG: A deliberate exception." if flag_debug
      }
      migr.down {
        puts "DEBUG(migration#{File.basename(__FILE__).split('_')[0]}): Tra-counts(Be4)(all,Eng(0),Pla(some))=#{_calc_trans_counts.inspect}" if flag_debug
        Translation.where(translatable_type: "PlayRole").update_all(translatable_type: "EngageEventItemHow")
        puts "DEBUG(migration#{File.basename(__FILE__).split('_')[0]}): Tra-counts(Aft)(all,Eng(some),Pla(0))=#{_calc_trans_counts.inspect}" if flag_debug
        raise "DEBUG: A deliberate exception." if flag_debug
      }
    end
  end
end
