# coding: utf-8
# == Schema Information
#
# Table name: channel_owners
#
#  id                                         :bigint           not null, primary key
#  note                                       :text
#  themselves(true if identical to an Artist) :boolean          default(FALSE)
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  artist_id                                  :bigint
#  create_user_id                             :bigint
#  update_user_id                             :bigint
#
# Indexes
#
#  index_channel_owners_on_artist_id       (artist_id)
#  index_channel_owners_on_create_user_id  (create_user_id)
#  index_channel_owners_on_themselves      (themselves)
#  index_channel_owners_on_update_user_id  (update_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (artist_id => artists.id)
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
require "test_helper"

class ChannelOwnerTest < ActiveSupport::TestCase
  test "fixtures" do
    assert ChannelOwner.unknown
    tra = translations(:channel_owner_unknown_en)
    assert_match(/^Unknown\b/, tra.title)
    assert tra.translatable
    assert_equal ChannelOwner.unknown, tra.translatable

    mdl = channel_owners(:channel_owner_haramichan)
    assert        mdl.themselves
    assert_equal "HARAMIchan", (tit=mdl.best_translations[:en].title), "Failed with #{mdl.inspect}"
    assert_equal mdl.artist.best_translations[:en].title, tit

    mdl = channel_owners(:channel_owner_saki_kubota)
    assert        mdl.themselves
    assert_equal artists(:artist_saki_kubota).title, mdl.best_translations[:ja].title
  end

  test "uniqueness and validation" do
    #assert_raises(ActiveRecord::RecordInvalid){
    #  ChannelOwner.create!( note: "") }     # When no entries have the default value, this passes!
    hstra = {langcode: "en", title: "A B Smith", is_orig: true}

    mdl1 = ChannelOwner.new( themselves: true )
    mdl1.unsaved_translations << Translation.new(hstra)
    refute mdl1.valid?  # Artist can't be blank when 'themselves?' is checked.

    mdl1.themselves = false
    mdl1.save!

    mdl2 = ChannelOwner.new( themselves: false )
    mdl2.unsaved_translations << Translation.new(hstra)
    #refute  mdl2.valid?  # This should refute!
    assert_raise(ActiveRecord::RecordInvalid){
      mdl2.save! }
  end

  test "validations and create_basic!" do
    art = artists(:artist_proclaimers)

    chan1 = ChannelOwner.new(title: art.title(langcode: :en), langcode: "en", is_orig: false, themselves: true, artist: art)
    assert_equal 1, chan1.unsaved_translations.size, "#{chan1.unsaved_translations}"
    refute chan1.valid?  # has a different unsaved_translations from the parent Artist's counterpart for language "en"

    chan1.set_unsaved_translations_from_artist
    assert chan1.valid?

    chan1.unsaved_translations << Translation.new(title: art.title(langcode: :en), langcode: "en", is_orig: false)
    refute chan1.valid? # must have exact unsaved_translations corresponding to the parent Artist but has zero (or multiple) Translations for language "en"

    chan1.unsaved_translations.pop
    assert chan1.valid?

    chan1.unsaved_translations << Translation.new(title: "naiyo", langcode: "zh", is_orig: false)
    refute chan1.valid? # has the unsaved_translations with a langcode absent in the parent Artist's counterparts # <= cannot be added as the parent Artist does not have a Translation for langcode="zh"

    chan1.unsaved_translations.pop
    assert chan1.valid?

    chan1.save!
    chan1.reload
    art.reload

    assert_equal chan1, art.channel_owner
    assert_equal chan1.title(langcode: :en), art.title(langcode: :en)

    assert_raises(ActiveRecord::RecordInvalid){ # Themselves  cannot have themselves==true with this Artist because another ChannelOwner is alreay defined for them.
            ChannelOwner.create_basic!(title: "dummy", langcode: "en", is_orig: false, themselves: true, artist: art, note: "chan2-dayo") }

    chan1.destroy!
    chan2 = ChannelOwner.create_basic!(title: "dummy", langcode: "en", is_orig: false, themselves: true, artist: art, note: "chan2-dayo")
    # both chan2 and artist are already reloaded.

    art.reload
    assert_equal "chan2-dayo", chan2.note
    assert_equal chan2, art.channel_owner
    assert_equal chan2.title(langcode: :en), art.title(langcode: :en)
  end

  test "update and themselves" do
    art = artists(:artist_proclaimers)
    art.translations << Translation.new(title: "2nd-t", langcode: "ja", is_orig: false, weight: 99999)
    art.reload

    chan1 = ChannelOwner.create_basic!(title: (tit1="Another-one"), langcode: "en", is_orig: true, themselves: false, note: "chan1")
    assert_equal "chan1", chan1.note
    assert_equal tit1,    chan1.title
    chan1.translations << Translation.new(title: "en-chan2", langcode: "en", is_orig: false, weight: 99999)
    chan1.translations << Translation.new(title: "en-chan3", langcode: "en", is_orig: false, weight: 99999)
    chan1.translations << Translation.new(title: "fr-chan1", langcode: "fr", is_orig: false, weight: 99999)
    chan1.reload

    chan1.themselves = true
    chan1.artist = art
    chan1.valid?
    refute chan1.valid?, "#{chan1.errors.inspect}" # must have exact unsaved_translations corresponding to the parent Artist but has zero (or multiple) Translations for language "en"

    chan1.synchronize_translations_to_artist  # in reality this should be enclosed with a transaction
    assert_equal art,       chan1.artist
    chan1.valid?
    assert chan1.valid?, "#{chan1.errors.inspect}"
    assert_equal art,       chan1.artist
    chan1.save!

    chan1.reload
    art.reload
    assert_equal "chan1",   chan1.note, 'sanity check'
    assert_equal art,       chan1.artist
    refute_equal tit1,      chan1.title
    assert_equal art.title, chan1.title
    assert_equal art.translations.size, chan1.translations.size
    assert_equal %w(en ja), chan1.best_translations.keys.sort
  end

  test "associations" do
    assert_nothing_raised{ ChannelOwner.first.channels }

    art = artists(:artist_proclaimers)

    chan1 = ChannelOwner.create_basic!(title: art.title(langcode: :en), langcode: "en", themselves: true, artist: art)
    assert_equal art, chan1.artist

    tra = Translation.new(title: "Proclaimers, Les", langcode: "fr", is_orig: false, weight: 0, note: (tmpnote="naiyo-fr"))
    art.translations << tra
    art.reload
    tra.reload
    assert_equal tra, art.translations.where(note: tmpnote).first, 'sanity check'
    assert_equal tra, art.best_translations["fr"], 'sanity check'
    chan1.reload
    assert_equal tra.title, chan1.best_translations["fr"].title
  end
end
