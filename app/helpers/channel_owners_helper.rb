module ChannelOwnersHelper
  # If both owner and type are specified, or if for the first Channel, the default title is also included in the returned Hash.
  #
  # @return [Hash] for Channel#new GET parameters
  def channel_new_get_params(channel_owner: , channel_type: nil, channel_platform: nil)
    channel_type_in = channel_type
    channel_type ||= ChannelType.default(:HaramiVid)
    channel_platform ||= ChannelPlatform.default(:HaramiVid)
    hsret = {
      channel_owner_id:    channel_owner.id,
      channel_type_id:     channel_type.id,
      channel_platform_id: channel_platform.id,
    }.with_indifferent_access

    if !channel_type_in && Channel.find_by(hsret)
      hsret[:channel_type_id] = nil
    else
      tit = default_channel_title(channel_owner: channel_owner, channel_type: channel_type, channel_platform: channel_platform) # defined in channels_helper.rb
      hsret[:title] = tit
      hsret[:langcode] = tit.lcode  # singleton method for "tit"
    end
    hsret
  end
end
