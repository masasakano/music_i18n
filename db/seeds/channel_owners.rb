# coding: utf-8

require(File.dirname(__FILE__)+"/common.rb")  # defines: module Seeds

# Model: ChannelOwners
#
module Seeds::ChannelOwners
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # ChannelOwner

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    unknown: {
      ja: RECORD_CLASS::UNKNOWN_TITLES['ja'],
      en: RECORD_CLASS::UNKNOWN_TITLES['en'],
      fr: RECORD_CLASS::UNKNOWN_TITLES['fr'],
      orig_langcode: 'en',
      themselves: false,
      note: nil,
      #regex: Proc.new{RECORD_CLASS.unknown}  # to check potential duplicates for ChannelOwners
    },
    haramichan: {
      ja: 'ハラミちゃん',
      en: ['HARAMIchan', 'Harami-chan'],
      orig_langcode: 'ja',
      themselves: true,
      note: nil,
      regex: /^(ハラミ|harami(chan)?\b)/i,
    },
    kohmi: {
      ja: '広瀬香美',
      en: 'Kohmi Hirose',
      orig_langcode: 'ja',
      themselves: true,
      note: nil,
      regex: /^広瀬\s*香美/i,
    },
  }.with_indifferent_access  # SEED_DATA
  SEED_DATA.each_value{|eh| eh.with_indifferent_access}

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(themselves note))  # defined in seeds_common.rb, using RECORD_CLASS
  end

end  # module Seeds::ChannelOwners

