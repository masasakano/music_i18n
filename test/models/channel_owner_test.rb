# coding: utf-8
# == Schema Information
#
# Table name: channel_owners(Owner of a Channel)
#
#  id                                         :bigint           not null, primary key
#  note                                       :text
#  orig_locale(locale of original title)      :string(2)
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
    hstra = {langcode: "en", title: tit_smith="A B Smith", is_orig: true}

    mdl1 = ChannelOwner.new( themselves: true )
    # mdl1.unsaved_translations << Translation.new(hstra)
    mdl1.translations.build(**hstra)
    refute mdl1.valid?  # Artist can't be blank when 'themselves?' is checked.

    mdl1.themselves = false
    assert_difference('ChannelOwner.count*10 + Translation.count', 11){
      mdl1.save!}
    assert_nil mdl1.artist
    assert_equal 1, mdl1.translations.load.count
    tra1 = mdl1.translations.first
    assert_equal tit_smith, tra1.title
    assert_nil   tra1.sync_parent

    # Checking unique constraint on :title
    mdl2 = ChannelOwner.new( themselves: false )
    tra2 = mdl2.translations.build(**hstra)  # for in-memory operation
    # mdl2.unsaved_translations << Translation.new(hstra)
    refute mdl2.valid?
    assert_raise(ActiveRecord::RecordInvalid){
      mdl2.save! }

    mdl2.orig_locale = tra2.langcode = "fr"
    tit_orig2 = tra2.title = tra2.title+"-2"  # in-memory operation
    assert mdl2.valid?

    # Checking an associated Artist on :create
    art_lennon = artists(:artist2) # John Lennon
    assert             art_lennon.orig_locale, "checking fixtures"
    refute_equal "fr", art_lennon.orig_locale, "checking fixtures"  # Artist's langcode should be "en"
    mdl2.themselves = true
    mdl2.artist = art_lennon
    refute mdl2.valid?
    mdl2.translations.delete(tra2)   # Removes from memory
    art_lennon.translations.each do |etra|  # load 3 new Translations loaded from Lennon's Translations
      tra = mdl2.translations.build(etra.hash_attributes_to_sync)
      tra.sync_parent = etra
    end
    refute mdl2.valid?
    mdl2.orig_locale = art_lennon.orig_locale
    assert mdl2.valid?, mdl2.errors.inspect

    assert_equal 3, (n_art_trans=art_lennon.translations.count), "checking fixture"
    assert_difference('ChannelOwner.count*10 + Translation.count', 10+n_art_trans){
      mdl2.save!}  # creation succees, with 3 new Translation-s, copying from those of Artist

    mdl2.reload
    assert_equal art_lennon.orig_locale, mdl2.orig_locale  # should differ from the input "fr" (should be "en"), importing Artist's one

    art_tras = art_lennon.translations.load
    co_tras = mdl2.translations.load
    assert_nil   co_tras.find_by(title: tit_orig2), "Input translations should be ignored."
    assert_equal art_tras.size, co_tras.size
    assert_equal art_tras.size,     co_tras.map(&:sync_parent).uniq.compact.size
    assert_equal art_tras.ids.sort, co_tras.map(&:sync_parent).map(&:id).sort  # :sync_translation_id should be set appropriately.
    assert_equal art_tras.pluck(:title).sort, co_tras.pluck(:title).sort
  end

  test "validations and create_basic!" do
    art = artists(:artist_proclaimers)
    n_art_tras = art.translations.count

    chan1 = ChannelOwner.new(title: art.title(langcode: :en), langcode: "en", is_orig: false, themselves: true, artist: art)
    assert_equal 1, chan1.unsaved_translations.size, "#{chan1.unsaved_translations}"
    refute chan1.valid?  # has a different unsaved_translations from the parent Artist's counterpart for language "en"

    assert chan1.reset_by_artist
    assert chan1.valid?
    assert_empty    chan1.unsaved_translations, "reset_by_artist should have cleared @unsaved_translations when themselves is true, but..."

    chan1.translations << (tra=Translation.new(title: art.title(langcode: :en), langcode: "en", is_orig: false, note: "2nd-2"))
    refute chan1.valid? # must have exact unsaved_translations corresponding to the parent Artist but has zero (or multiple) Translations for language "en"
    chan1.translations.destroy tra
    assert chan1.valid?

    chan1.translations << (tra=Translation.new(title: "naiyo", langcode: "zh", is_orig: false, note: "2nd-3"))
    refute chan1.valid? # has the unsaved_translations with a langcode absent in the parent Artist's counterparts # <= cannot be added as the parent Artist does not have a Translation for langcode="zh"
    chan1.translations.destroy tra
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
    ## Preparation of Artist
    # art = artists(:artist_proclaimers)
    art = Artist.new(sex: Sex[1], note: "temporary Artist", orig_locale: "ko")
    art_tras = []
    art_tras << art.translations.build(title: "1st-Art-tra-ko", langcode: "ko", is_orig: true,  weight: 100)
    art_tras << art.translations.build(title: "2nd-Art-tra-ko", langcode: "ko", is_orig: false, weight: 101, note: "Note of 2nd-Art-ko") # must have two "ko" Translations for the tests below
    art_tras << art.translations.build(title: "Art-tra-ja", ruby: "アートトラジェイエー", langcode: "ja", is_orig: false, weight: 102)
    art.save!
    assert_equal "ko", art.orig_locale
    n_art_trans = art.translations.count 

    art2_locale = "es"
    art2_title = "es-2nd Artist"
    art2 = Artist.create!(sex: Sex[1], note: "2nd tmp Artist", orig_locale: art2_locale, translations_attributes: [{langcode: art2_locale, title: art2_title, is_orig: true, weight: 131}] )

    ## Preparation of ChannelOwner (no Artist association)
    tit1 = tit_chow1_orig = "Another-ChOw"
    chow1 = ChannelOwner.create_basic!(title: tit_chow1_orig, langcode: "en", is_orig: true, themselves: false, note: "chow1", translation_weight: 2000)
    assert_equal "chow1", chow1.note
    assert_equal "en",    chow1.orig_locale, "sanity-check"
    assert_equal tit1,    chow1.title
    tras = chow1.translations.load
    assert_equal 1,       tras.size
    chow1.translations << Translation.new(title: "en-chan2", langcode: "en", is_orig: false, weight: 2001)
    chow1.translations << Translation.new(title: "en-chan3", langcode: "en", is_orig: false, weight: 2002)
    chow1.translations << Translation.new(title: "fr-chow1", langcode: "fr", is_orig: false, weight: 2003)
    chow1.reload
    assert_equal 4, (n_trans_orig=chow1.translations.count)
    refute_equal     n_trans_orig, art.translations.count
    assert_empty tras.map(&:sync_parent).uniq.compact

    ## Updates ChannelOwner to have an Artist association
    chow1.themselves = true
    chow1.artist = art
    assert_equal art,       chow1.artist

    refute chow1.valid?, "#{chow1.errors.inspect}" # must have exact unsaved_translations corresponding to the parent Artist but has zero (or multiple) Translations for language "en"

    chow1.themselves = false
    chow1.reset_by_artist(force: true)  # wrapper of synchronize_translations_to_artist
    # chow1.synchronize_translations_to_artist  # NOTE: This used to need to be enclosed with a transaction if called from Controller but not anymore!
    assert chow1.themselves, "should have been reset, but..."
    assert_equal art,       chow1.artist
    assert chow1.valid?, "#{chow1.errors.inspect}"

    chow1.save!  # Now, Translations are synced with the parent Artist's

    chow1.reload
    art.reload
    assert_equal chow1,  art.channel_owner
    assert_equal "chow1",   chow1.note, 'sanity check'
    assert_equal art,       chow1.artist

    tras = chow1.translations.load
    refute_equal n_trans_orig, tras.size
    assert_equal n_art_trans,  tras.size, [tras.reload.pluck(:langcode,:title), tras].inspect
    
    assert_equal n_art_trans, tras.map(&:sync_parent).uniq.compact.size
    assert_equal art.translations.ids.sort, tras.map(&:sync_parent).map(&:id).sort

    refute_equal tit1,      chow1.title
    assert_equal art.title, chow1.title

    _verify_assimilate_artist(chow1)
    #assert_equal %w(en ja), chow1.best_translations.keys.sort

    etra = tras.first
    assert_operator etra.updated_at, :<, etra.created_at, "Timestamp should have been modified when synced with Artist's but ..."

    # Synced Translation of ChannelOwner should not be modified in main columns (but #note)
    assert etra.sync_parent, "sanity check"
    tmp = etra.romaji
    etra.romaji = "Kore wa dame"
    refute etra.valid?
    etra.romaji = tmp
    assert etra.valid?
    etra.note = etra.note.to_s + " Something added."
    assert etra.valid?

    # Synced Translation of ChannelOwner should not be destroyed.
    assert_raises(ActiveRecord::RecordNotDestroyed){
      etra.destroy! }

    # Change in Artist's Translation should be propagated to ChannelOwner's
    art_tra_ja = art.translations.find_by(langcode: "ja")
    art_tra_ja_child = art_tra_ja.sync_child
    art_tra_ja.update!(langcode: "zh", weight: 249)
    assert_equal "zh", art_tra_ja.langcode, "sanity check"
    tra_act = chow1.translations.reset.find_by(langcode: "zh")
    assert_equal art_tra_ja_child.reload, tra_act
    assert_equal art_tra_ja.title, tra_act&.title
    assert_equal 249,              tra_act.weight

    # Destroying Artist's Translation should be propagated to ChannelOwner's
    art_tra2destroy = art_tras[1].reload  # not the best one
    art_tra2destroy_child = art_tra2destroy.sync_child 
    assert_difference('ChannelOwner.count*10 + Translation.count', -2, "should be cascade-destroyed, but..."){
      art_tra2destroy.destroy!
    }
    refute Translation.exists?(art_tra2destroy_child.id)  # Should have disappeared.

    # Change in Artist#orig_locale be propagated to ChannelOwner
    art.update!(orig_locale: "zh")
    assert_equal "zh", chow1.reload.orig_locale
    _verify_assimilate_artist(chow1)

    # Associates to a different Artist
    #  which should updates the associated Translation-s completely.
    ar_art2_tran = art2.translations.load
    n_diff_trans = ar_art2_tran.size - art.translations.reset.size
    chow1.artist = art2 
    chow1.reset_by_artist
    assert_difference('ChannelOwner.count*10 + Translation.count', n_diff_trans){
      chow1.valid?
      assert chow1.save, "Validation ERROR: "+chow1.errors.inspect
    }
    tras = chow1.translations.reset
     # Checking if Translations are now completely updated.
    assert_equal art2.orig_locale, chow1.orig_locale
    assert_equal ar_art2_tran.size, tras.size
    assert_equal ar_art2_tran.size, (parents=tras.map(&:sync_parent)).compact.uniq.size
    assert_equal [art2], parents.map(&:translatable)
    assert_equal ar_art2_tran.map(&:title).sort, tras.map(&:title).sort

    # Decouple Translations by updating
    chow1.reload
    chow1.assign_attributes(themselves: false, artist_id: nil)
    refute chow1.valid?  # b/c Translation#sync_translation_id should be nil
    chow1.reset_by_artist
    assert chow1.valid?, "#{chow1.errors.inspect}"

    assert_no_difference('ChannelOwner.count*10 + Translation.count'){
      assert chow1.save
    }
    tras = chow1.translations.reset
    assert_empty tras.map(&:sync_parent).compact

    # Re-couple with an Artist
    chow1.reload
    created_at_be4 = chow1.ordered_translations.first.created_at
    chow1.assign_attributes(themselves: true, artist: art2)
    refute chow1.valid?  # b/c Translation#sync_translation_id should be nil
    chow1.reset_by_artist
    assert chow1.valid?, "#{chow1.errors.inspect}"
    assert_no_difference('ChannelOwner.count*10 + Translation.count'){
      assert chow1.save
    }
    chow1.reload
    assert_equal created_at_be4, chow1.ordered_translations.first.created_at  # Because the operation updates an existing record, as opposed to replacing it (because replacing would raise a unique violation for Translation during in-memory operation).

    # Adding a Translation to Artist should be propagated to child ChannelOwner
    art2.reload
    assert art2.valid?
    attrs = Translation::SYNC_ATTRIBUTES.index_with { |attr| art_tras[0].public_send(attr) }
    attrs[:is_orig] = false
    tra = art2.translations.build(**attrs)
    refute art2.valid?
    tra.langcode = "de"
    assert art2.valid?

    chow_id = chow1.id
    assert_difference("ChannelOwner.find(#{chow_id}).translations.count", 1, "Added Translation to Artist should be propagated to ChannelOwner, but..."){
      assert_difference('ChannelOwner.count*10 + Translation.count', 2){
        assert art2.save, art2.errors.inspect
      }
    }

    # Destroying attempt of an Artist should raise an Exception
    art2.reload
    assert_equal chow1, art2.channel_owner
    assert_raises(ActiveRecord::DeleteRestrictionError) {
      refute art2.destroy }

    # Destroying ChannelOwner and its Translations should succeed
    assert_difference('ChannelOwner.count*10 + Translation.count', -(10+chow1.translations.count)){
      assert chow1.destroy
    }
  end

    # Verify if Translations between ChannelOwner and parent Artist are all consistent
    #
    # @param is_saved [Boolean] if true, ChannelOwner record has been already saved
    def _verify_assimilate_artist(record, art=nil, is_saved: true)
      record.reload if is_saved
      cho_tras = record.translations.load
      art ||= record.artist
      art.reload if is_saved
      art_tras =    art.translations.load

      assert_equal art_tras.size,  cho_tras.size
      if is_saved
        assert_equal art_tras.size,     cho_tras.map(&:sync_parent).uniq.compact.size
        assert_equal art_tras.ids.sort, cho_tras.map(&:sync_parent).map(&:id).sort
      end

      cho_tras.each_with_index do |etra, i_tra|
        tra_parent = etra.sync_parent
        Translation::SYNC_ATTRIBUTES.each do |eatt|
          exp = tra_parent.send(eatt).presence
          msg = "[#{etra.langcode}] :#{eatt} differ in Translations between ChannelOwner and Artist"
          if !exp
            assert_nil        etra.send(eatt).presence, msg
          else
            assert_equal exp, etra.send(eatt).presence, msg 
          end
        end
      end
    end
    private :_verify_assimilate_artist

  test "associations" do
    assert_nothing_raised{ ChannelOwner.first.channels }

    art = artists(:artist_proclaimers)

    chan1 = ChannelOwner.create_basic!(title: art.title(langcode: :en), langcode: "en", themselves: true, artist: art)
    assert_equal art, chan1.artist
    assert_equal art.orig_locale, chan1.orig_locale, "sanity-check"

    tra = Translation.new(title: "Proclaimers, Les", langcode: "fr", is_orig: false, weight: 0, note: (tmpnote="naiyo-fr"))
    art.translations << tra
    art.reload
    tra.reload
    assert_equal tra, art.translations.where(note: tmpnote).first, 'sanity check'
    assert_equal tra, art.best_translations["fr"], 'sanity check'
    chan1.reload
    assert_equal tra.title, chan1.best_translations["fr"]&.title, chan1.best_translations
  end
end
