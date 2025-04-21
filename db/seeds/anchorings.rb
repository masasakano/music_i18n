# coding: utf-8

require_relative("common.rb")  # defines: module Seeds
require_relative("event_groups.rb")
require_relative("channels.rb")
require_relative("urls.rb")

# Model: Anchoring
#
# NOTE: SiteCategory must be loaded beforehand!
module Seeds::Anchorings
  extend Seeds::Common

  # Corresponding Active Record class
  RECORD_CLASS = self.name.split("::")[-1].singularize.constantize # Anchoring

  # Everything is a function
  module_function

  # Data to seed
  SEED_DATA = {
    url_haramichan_main_artist_harami: {
      url_id: Proc.new{domain = DomainTitle.select_regex(:titles, /^ハラミちゃん(.*(ホームページ|ウェブサイト|Website))$/, sql_regexp: true).order(:created_at).first.domains.order(:created_at).first; cand = domain.urls.where(url: "https://"+domain.domain).order(:created_at); (cand.exists? ? cand.first : domain.urls.order(:created_at).first).id},
      anchorable_type: "Artist",
      anchorable_id: Proc.new{Artist.default(:HaramiVid).id},
      note: "HARAMIchan Homepage",
      regex: Proc.new{Artist.default(:HaramiVid).urls.order(:created_at).first},  # existing record
    },
  }.with_indifferent_access  # SEED_DATA

  # this is properly set by load_seeds (the contents may be existing ones or new ones)
  MODELS = SEED_DATA.keys.map{|i| [i, nil]}.to_h

  # Main routine to seed.
  #
  # Constant Hash MODELS is set so that the seeded models are accessible.
  #
  # @return [Integer] Number of created/updated entries
  def load_seeds
    _load_seeds_core(%i(url_id anchorable_type anchorable_id note))  # defined in seeds/common.rb, using RECORD_CLASS
  end

end  # module Seeds::Anchorings

