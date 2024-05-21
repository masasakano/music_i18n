# coding: utf-8
module ChannelsHelper
  # @param channel_owner: [ChannelOwner] mandatory
  # @return [String] title
  def default_channel_title(channel_owner: , channel_type: nil, channel_platform: nil)
    channel_type ||= ChannelType.default(:HaramiVid)
    channel_platform ||= ChannelPlatform.default(:HaramiVid)

    retstr = Channel.def_initial_trans_str(
      langcode: nil,
      channel_owner:    channel_owner,
      channel_type:     channel_type,
      channel_platform: channel_platform,
      force: true
    )

    retstr.lcode = "ja" if contain_asian_char?(retstr)  # defined in ModuleCommon
    retstr
  end
end
