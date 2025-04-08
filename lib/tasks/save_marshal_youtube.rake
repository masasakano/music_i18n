# Saves marshal-ed youtube data
#
# This Rake task saves the Youtube-API data with Marshal on a file to avoid repeated
# Google/Youtube API calls during testing.
#
# HaramiVids::FetchYoutubeDataController, which uses Youtube API, looks up
# at ENV["UPDATE_YOUTUBE_MARSHAL"], but this Rake task does not and always saves/updates the file,
# as long as the retrieval of the meta data from Youtube is successful.
#
# Usage: bin/rails save_marshal_youtube
#

require Rails.root.join("test/helpers/marshaled")  # loads the constant MARSHALED

# @param yt2save [Google::Apis::YoutubeV3::Channel, Google::Apis::YoutubeV3::Video]
# @param category [Symbol] either :channel or :video
# @param kwd [Symbol] The key of the hash. See /test/helpers/marshaled.rb
# @return [String, NilClass] Full path of the saved marshal file if successful, else nil
def save_marshal_youtube_save_new(taskname, yt2save, category, kwd)
  if !(hs_category=MARSHALED[:youtube][category]).respond_to?(:[]) || !(hs_data=hs_category[kwd]).respond_to?(:[]) 
    raise "ERROR(#{taskname}): Wrong key word pair #{[category, kwd].inspect}. Contact the code developer."
  end

  fullpath = get_fullpath_test_data(hs_data[:basename])  # gets an existing file; defined in application_helper.rb
  fullpath ||= ApplicationHelper::DEF_FIXTURE_DATA_DIR + "/" + hs_data[:basename]  # gets a new filename.

  begin
    save_marshal(yt2save, fullpath) # defined in ApplicationHelper

    print "NOTE: saving Youtube object '#{kwd.capitalize}':"
    p yt2save
    puts "NOTE(#{taskname}): (#{Time.current}) Updated '#{kwd.capitalize}' Youtube data with the API at #{fullpath}"
    fullpath
  rescue => er
    warn "ERROR(#{taskname}): Failed to save '#{kwd.capitalize}' Youtube data with the API at #{fullpath} : "+er.message
    return nil
  end
end

# method names
SaveMarshalYoutubeMethods = {
  video:   :get_yt_video,
  channel: :get_yt_channel,
}.with_indifferent_access

# Task: save_marshal_youtube
#
# Usage: bin/rails save_marshal_youtube
#
# This forcibly updates (or newly saves) ALL the marshal-ed data.
# The directory is {ApplicationHelper::DEF_FIXTURE_DATA_DIR}
#
# If any of saving attempts fails, exit 1 at the end, after all have been processed.
task :save_marshal_youtube => :environment do |taskname|
  include ApplicationHelper # for save_marshal
  include ModuleYoutubeApiAux

  youtube = set_youtube(set_instance_var: false)  # NOT sets @youtube

  arret = []
  MARSHALED[:youtube].each_pair do |category, hsval1|
    hsval1.each_key do |kwd|
      yid = hsval1[kwd][:id]
      yt2save = send(SaveMarshalYoutubeMethods[category], yid, youtube: youtube, set_instance_var: false, use_cache_test: false) # NOT sets @yt_video or @yt_channel
      if !yt2save
        warn "ERROR(#{taskname}): Failed to retrieve the meta data for #{category.to_s} #{yid.inspect} from Youtube. Aborted. Ret=#{yt2save.inspect}"
        exit 1
      end
      arret << save_marshal_youtube_save_new(taskname, yt2save, category, kwd)
    end
  end

  exit 1 if arret.any?(nil)

end

