# -*- coding: utf-8 -*-

# Defines top-level constants that are used both by the application proper and in tests
#

# Constant that point the marshal-ed data.
MARSHALED = {
  youtube: {
    channel: {
      harami: {
        id: "UCr4fZBNv69P-09f98l7CshA",  # == channels(:channel_haramichan_youtube_main).id_at_platform  (in Test)
        custom_url: "haramipiano_main", # without preceding "@"
        basename: "youtube_channel_harami.marshal",
      }.with_indifferent_access,
      kohmi: {
        id: "UCPkjL7jAJhrZ3e4-NlsGt-Q",  # == channels(:channel_haramichan_youtube_main).id_at_platform  (in Test)
        custom_url: "officialyoutubechannel8034", # without preceding "@"
        basename: "youtube_channel_kohmi.marshal",
      }.with_indifferent_access,
    }.with_indifferent_access,
    video: {
      zenzenzense: {
        id: "hV_L7BkwioY",  # == harami1129s(:harami1129_zenzenzense1).link_root  (in Test)
        basename: "youtube_zenzenzense.marshal",
      }.with_indifferent_access,
    }.with_indifferent_access,
  }.with_indifferent_access,
}.with_indifferent_access

