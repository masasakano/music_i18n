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
      ja: ['ハラミちゃん', 'ハラミ'],
      en: ['HARAMIchan', 'Harami-chan'],
      orig_langcode: 'ja',
      themselves: true,
      artist: Proc.new{Artist.default(:HaramiVid)},  # Artist and its Translations must be defined before this is executed.
      note: nil,
      regex: /^(ハラミ|harami(chan)?\b)/i,
    },
    kohmi: {
      ja: '広瀬香美',
      en: 'Kohmi Hirose',
      orig_langcode: 'ja',
      themselves: true,
      regex: (rege=(/^広瀬\s*香美/i)),
      artist: Proc.new{Artist.select_regex(:title, rege, langcode: 'ja', sql_regexp: true).distinct.first},
      note: nil,
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
    proc_b4validate = Proc.new{ |model|
      model.set_unsaved_translations_from_artist if model.themselves
    }
    _load_seeds_core(%i(themselves artist note), proc_b4validate: proc_b4validate)  # defined in seeds_common.rb, using RECORD_CLASS
  end

end  # module Seeds::ChannelOwners

