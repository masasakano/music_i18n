# Saves marshal-ed youtube data
#
# This Rake task saves the Youtube-API data with Marshal on a file to avoid repeated
# Google/Youtube API calls during testing.
# This Rake task saves the Youtube-API data with Marshal on a file to avoid repeated
#
# In HaramiVids::FetchYoutubeDataController, ENV["UPDATE_YOUTUBE_MARSHAL"] is looked up at,
# but this Rake task does not and saves/updates the file always, as long as
# the retrieval of the meta data from Youtube is successful.
#
# Usage: bin/rails save_marshal_youtube
#

require Rails.root.join("test/helpers/marshaled")  # loads the constant MARSHALED

# Task: save_marshal_youtube
#
# Usage: bin/rails save_marshal_youtube
#
# This forcibly update the marshal-ed data.
# The directory is ApplicationHelper::DEF_FIXTURE_DATA_DIR
task :save_marshal_youtube => :environment do |taskname|
  include ApplicationHelper # for save_marshal
  include ModuleYoutubeApiAux

  set_youtube                   # sets @youtube
  yid = MARSHALED[:youtube][:video][:zenzenzense][:id]
  yt2save = get_yt_video(yid, use_cache_test: false)  # sets @yt_video
  if !yt2save
    warn "ERROR(#{taskname}): Failed to retrieve the meta data for video #{yid.inspect} from Youtube. Aborted. Ret=#{yt2save.inspect}"
    exit 1
  end

  fullpath = get_fullpath_test_data(MARSHALED[:youtube][:video][:zenzenzense][:basename])  # defined in application_helper.rb
  fullpath ||= ApplicationHelper::DEF_FIXTURE_DATA_DIR + "/" + MARSHALED[:youtube][:video][:zenzenzense][:basename] 

  begin
    save_marshal(yt2save, fullpath) # defined in ApplicationHelper

    puts "NOTE: saved Youtube object:"
    p yt2save
    puts "NOTE(#{taskname}): (#{Time.current}) Updated 'Zenzenzense' Youtube data with the API at #{fullpath}"
  rescue => er
    warn "ERROR(#{taskname}): Failed to save 'Zenzenzense' Youtube data with the API at #{fullpath} : "+er.message
    exit 1
  end

end

