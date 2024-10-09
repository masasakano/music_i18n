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

  # html-safe anchor HTML like "<a href=...>...</a>" for Channel
  #
  # It is either https://www.youtube.com/channel/ABC or https://www.youtube.com/@HANDLE
  # The former is preferred in default.
  #
  # Other options include +link_title+, +target+. See application_helper.rb
  #
  # @param word [String] to highlight for the link
  # @param model [Channel]
  # @param prefer_handle: [Boolean] if true, URI for the handle (@something) is preferrably returned.
  # @param **kwds [Hash] passed to link_to_channel()
  # @return [String, NilClass] nil if no ID is defined in the model Channel
  def link_to_youtube_from_channel(word, model, prefer_handle: false, **kwds)
    cand_attrs = %i(id_at_platform id_human_at_platform)
    cand_attrs.reverse! if prefer_handle
    yid, att = cand_attrs.find{|i|
      ret = model.send(i)
      break [ret, i] if ret.present?
      nil
    }
    return if !yid
    link_to_channel(word, yid, kind: Channel::LINK_TO_CHANNEL_KINDS[att], platform: model.channel_platform.mname, **kwds) # defined in application_helper.rb
  end

  # Sort by the number of HaramiVid, but Channel-s wih a common ChannelOnwer should be grouped together.
  #
  # For those with the same ChannelOwner, they are sorted by ChannelPlatform and ChannelType
  # in this order, where ChannelPlatform has no particular order (hence using pIDs?)
  # but ChannelType has a weight column.
  #
  # == Algorithm
  #
  # 1. With Raiils-PostgreSQL, sort Channel-s according to the number of child HaramiVid
  #    and outputs the pairs of the pIDs of Channel and ChannelOwner as a Ruby (double) Array.
  # 2. In pure Ruby, Group Channels pIDs according to their ChannelOwners, preserving the order in (1)
  #    for the highest one among those with a common ChannelOwner.
  # 3. In each group of Channel-ChannelOwner pID pairs, sort them according to
  #    ChannelPlatform and ChannelType, while keeping the order in (2).
  # 4. Finally, drop the ChannelOwner ID in each pair and flatten the Array to
  #    make it a flat 1-dim Array of Channel pIDs
  # 5. Obtains the ordered Channels from the Array of pIDs.
  #
  # @return [Array<Channel>]
  def sort_channels_for_index(models=Channel.all)
    # sorted (ordered) according to the number of child HaramiVid-s
    dbl_ids = models.left_joins(:harami_vids).left_joins(:channel_owner).group(:id, "harami_vids.id", "channel_owners.id").order('COUNT(harami_vids.id) DESC').pluck("id", "channel_owners.id").uniq

    atm = []
    ar2 = dbl_ids.map.with_index{|da, ind|
      k = atm.find_index{|eat| eat == da[1]}
      atm << da[1]
      atm.uniq!
      [(k ? k : atm.size-1), ind] + da   # [Owner-ID-order-no, Original-order-no, Channel-ID, Owner-ID]
    }.sort{|a,b|
      ((c0=(a[0] <=> b[0])) != 0) ? c0 : (a[1] <=> b[1])
    }.map{|ej| ej[2..3]}  # sorted [[Channel-ID, Owner-ID], ...]; e.g., [[7,5],[6,5],[5,5], [8,2], [2,3],[1,3]]  # i.e., grouped over the 2nd-element (Owner-ID)

    aum = []
    ar2.each do |a3|
      if aum.empty? || (aum[-1][-1][-1] != a3[1])
        aum << [a3]
      else
        aum[-1] << a3
      end
    end
    # => [[[7,5],[6,5],[5,5]],
    #     [[8,2]],
    #     [[2,3],[1,3]], ]  # i.e., properly grouped with an Array

    aum.map!{|a4|
      a4.map{|a5| a5.first}
    }  # => Array<Array<Channel>>:   # Now, ChannelOwner is eliminated.
    # => [[7, 6, 5],   # Channels for Owner-1
    #     [8],         # Channel  for Owner-2
    #     [2, 1], ]    # Channels for Owner-3

    chan_ids = aum.map{ |ed2|
      if ed2.size > 1
        Channel.where(id: ed2).joins(:channel_platform).joins(:channel_type).order("channel_platforms.id", "channel_types.weight").ids
      else
        ed2
      end
    }.flatten

    Channel.find chan_ids
  end
end
