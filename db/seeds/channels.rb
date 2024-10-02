# coding: utf-8

require_relative("common.rb")  # defines: module Seeds
require_relative("channel_owners.rb")
require_relative("channel_types.rb")
require_relative("channel_platforms.rb")

# Model: Channels
#
# NOTE: ChannelPlatform, ChannelType, ChannelOwner, must be loaded beforehand!
module Seeds::Channels
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # Channel

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      channel_owner:    Proc.new{ChannelOwner.unknown(reload: true)},
      channel_type:     Proc.new{ChannelType.unknown(reload: true)},
      channel_platform: Proc.new{ChannelPlatform.unknown(reload: true)},
      note: nil,
      regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for Channels
    },
    haramichan_youtube_main: {
      ja: 'ハラミちゃん',
      en: ['HARAMIchan', 'Harami-chan'],
      orig_langcode: 'ja',
      channel_owner:    Proc.new{ChannelOwner.select_regex(:titles, Seeds::ChannelOwners::SEED_DATA[:haramichan][:regex], sql_regexp: true).first},
      channel_type:     Proc.new{ChannelType.where(    mname: Seeds::ChannelTypes::SEED_DATA[:main][:mname]).first},
      channel_platform: Proc.new{ChannelPlatform.where(mname: Seeds::ChannelPlatforms::SEED_DATA[:youtube][:mname]).first},
      id_at_platform: 'UCr4fZBNv69P-09f98l7CshA',
      note: nil,
    },
    kohmi_youtube_main: {
      ja: '広瀬香美',
      en: 'Kohmi Hirose',
      orig_langcode: 'ja',
      channel_owner:    Proc.new{ChannelOwner.select_regex(:titles, Seeds::ChannelOwners::SEED_DATA[:kohmi][:regex], sql_regexp: true).first},
      channel_type:     Proc.new{ChannelType.where(    mname: Seeds::ChannelTypes::SEED_DATA[:main][:mname]).first},
      channel_platform: Proc.new{ChannelPlatform.where(mname: Seeds::ChannelPlatforms::SEED_DATA[:youtube][:mname]).first},
      id_at_platform: 'UCPkjL7jAJhrZ3e4-NlsGt-Q',
      note: nil,
    },
  }.with_indifferent_access  # SEED_DATA

  # Set the common create_user, update_user, regex
  proc_regex_find = Proc.new{|ehs, key| Seeds::Channels.find_record(ehs, key)}
  SEED_DATA.each_pair do |ek, ev|
    ev[:create_user_id] = :special_sysadmin_id
    ev[:update_user_id] = nil
    ev[:regex] ||= proc_regex_find  # Finds the matching existing record
  end
  SEED_DATA.each_value{|eh| eh.with_indifferent_access}

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Find the matching existing Channel, based on the referenced IDs, which are based on "mname" etc
  #
  # @return [Channel]
  def self.find_record(ehs, key)
    hs = %w(channel_owner channel_type channel_platform).map{|ek|
      [ek, ehs[ek].call]  # Basically, channel_onwer (etc) of the same SEES=DS, which is dynamically determiined with Proc
    }.to_h
    # puts "DEBUG(#{File.basename __FILE__}:#{__method__}):hs=#{hs.map{|k,v| [k,[v.id,v.title]]}.to_h} : #{Channel.find_by(hs) ? 'Found.' : 'Non-existent.'}" ###
    Channel.find_by(hs)
  end

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(channel_owner channel_type channel_platform create_user_id update_user_id note))  # defined in seeds_common.rb, using RECORD_CLASS
  end

end  # module Seeds::Channels

