# coding: utf-8
# == Schema Information
#
# Table name: channels
#
#  id                                                                     :bigint           not null, primary key
#  id_at_platform(Channel-ID at the remote platform)                      :string
#  id_human_at_platform(Human-readable Channel-ID at remote prefixed <@>) :string
#  note                                                                   :text
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  channel_owner_id                                                       :bigint           not null
#  channel_platform_id                                                    :bigint           not null
#  channel_type_id                                                        :bigint           not null
#  create_user_id                                                         :bigint
#  update_user_id                                                         :bigint
#
# Indexes
#
#  index_channels_on_channel_owner_id      (channel_owner_id)
#  index_channels_on_channel_platform_id   (channel_platform_id)
#  index_channels_on_channel_type_id       (channel_type_id)
#  index_channels_on_create_user_id        (create_user_id)
#  index_channels_on_id_at_platform        (id_at_platform)
#  index_channels_on_id_human_at_platform  (id_human_at_platform)
#  index_channels_on_update_user_id        (update_user_id)
#  index_unique_all3                       (channel_owner_id,channel_type_id,channel_platform_id) UNIQUE
#  index_unique_channel_platform_its_id    (channel_platform_id,id_at_platform) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (channel_owner_id => channel_owners.id)
#  fk_rails_...  (channel_platform_id => channel_platforms.id)
#  fk_rails_...  (channel_type_id => channel_types.id)
#  fk_rails_...  (create_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (update_user_id => users.id) ON DELETE => nullify
#
require "test_helper"

class ChannelTest < ActiveSupport::TestCase

  test "fixtures" do
    assert Channel.unknown
    tra = translations(:channel_unknown_en)
    assert_match(/^Unknown\b/, tra.title)
    assert tra.translatable
    assert_equal Channel.unknown, tra.translatable

    mdl = channels(:channel_haramichan_youtube_main)
    assert        mdl.create_user
    assert_equal "HARAMIchan", mdl.best_translations[:en].title

    mdl = channels(:channel_haramichan_youtube_main)
    assert mdl.valid?, "mdl=#{mdl.inspect}"

    #mdl = channels(:channel_saki_kubota)
    #assert        mdl.themselves
    #assert_equal artists(:artist_saki_kubota).title, mdl.best_translations[:ja].title

    assert ChannelType.default(:HaramiVid), "ChannelType.default(:HaramiVid)"
    assert_equal ChannelType.find_by(mname: :main), ChannelType.default(:HaramiVid)
    assert ChannelPlatform.default(:HaramiVid), "ChannelPlatform.default(:HaramiVid)"
    assert_equal ChannelPlatform.find_by(mname: :youtube), ChannelPlatform.default(:HaramiVid)
    assert ChannelOwner.primary
    assert Channel.primary, "Channel.primary"
  end

  test "validation_id_human_at_platform" do
    mdl_base = channels(:channel_haramichan_youtube_main)
    mdl_base_chan2 = { channel_owner: mdl_base.channel_owner, 
                       channel_platform: mdl_base.channel_platform, }
    mdl = Channel.new( channel_type: mdl_base.channel_type, **mdl_base_chan2 )
    mdl.unsaved_translations << Translation.new(langcode: "en", title: "dummy-149", is_orig: true)

    # most basic unique constraint on the combination of (owner, platform, type)
    assert_raises(ActiveRecord::RecordNotUnique){ mdl.save!(validate: false) } # DB level
    assert_raises(ActiveRecord::RecordInvalid){   mdl.save! }                  # Rails level

    typea = channel_types(:channel_type_agent)
    mdl.channel_type = typea
    refute Channel.where(channel_type: typea, **mdl_base_chan2).present?  # sanity check just in case.
    mdl.save!
    mdl.reload
    mdl_tra = mdl.best_translation

    # Checks if the unique constraint on id_at_platform ignores nil.
    typeb = channel_types(:channel_type_blog)
    mdl2 = mdl.dup
    tra = mdl_tra.dup
    tra.title = mdl_tra.title + "999"
    mdl2.unsaved_translations << tra
    mdl2.channel_type = typeb
    refute Channel.where(channel_type: typeb, **mdl_base_chan2).present?  # sanity check just in case.
    mdl2.save!  # This should work, because mdl and mdl2 have different ChannelType-s and both have nil id_at_platform (where nil id_at_platform should be always ignored).

    ## Validates two attributes
    %w(id_at_platform id_human_at_platform).each do |att|
      # unique constraint (Rails-level only) on the combination of (id_(human_)at_platform, channel_platform)
      mdl.send(att+"=", mdl_base.send(att))
      if "id_at_platform" == att
        assert_raises(ActiveRecord::RecordNotUnique){ mdl.save!(validate: false) } # DB level
      end
      refute mdl.valid?
      assert_raises(ActiveRecord::RecordInvalid){   mdl.save! }                  # Rails level
      # NOTE: if (channel_platform == :other) and id_at_platform-s agree, it would raise a validation AND DB-level errors(!). For Channels with (channel_platform == :other), you should leave id_at_platform-s blank and instead record them in note if need be (though there is no application-level check for this).

      # some characters are prohibited in id_at_platform
      mdl.send(att+"=", "")  # e.g., mdl.id_at_platform = ""
      refute mdl.valid?, "An empty String (but nil) should not be allowed for #{att}, but..."  # This validation is necessary to activate the DB-level constraint.
      mdl.send(att+"=", nil)
      assert mdl.valid?

      word_ok = mdl_base.send(att)+"9999"
      mdl.send(att+"=", word_ok)
      assert mdl.valid?

      ar2chk = ["語", " "]  # "@" may be allowed for ID on Youtube?  I don't know!  On Twitter, "@" is definitely not allowed, but you should use id_human_at_platform only?
      ar2chk << "@" if "id_human_at_platform" == att
      ["語", " "].each do |ec|
        mdl.send(att) << ec 
        refute mdl.valid?, "Unexpectedly passed with #{att}=#{mdl.send(att).inspect}"
        mdl.send(att+"=", word_ok)
        assert mdl.valid?  # sanity check
      end
      mdl.save!  # must work.
    end # %w(id_at_platform id_human_at_platform).each do |att|
  end   # test "validation_id_human_at_platform" do

  test "def_initial_translations" do
    hstmpl = {channel_platform: ChannelPlatform.default(:HaramiVid), channel_type: ChannelType.default(:HaramiVid)}

    co = co1 = ChannelOwner.create_basic!(title: "日本語っちゃ", langcode: "ja")
    chan = Channel.new(channel_owner: co, **hstmpl)
    transs = chan.def_initial_translations
    assert_equal 1, transs.size  # because ChannelOwner's title is Japanese only, this cannot create EN or FR titles.

    co = co2 = ChannelOwner.create_basic!(title: "An English Title 2", langcode: "en")
    chan = Channel.new(channel_owner: co, **hstmpl)
    transs = chan.def_initial_translations
    assert_equal 3, transs.size
  end

  test "methods" do
    assert channels(:channel_haramichan_youtube_main).on_youtube?
    refute channels(:channel_unknown).on_youtube?
  end 

  test "association" do
    rec0 = Channel.new(title: 'a', langcode: 'en', channel_owner: ChannelOwner.second, channel_platform: ChannelPlatform.last, channel_type: ChannelType.last)
    rec1 = Channel.new(title: 'a', langcode: 'en', channel_owner: ChannelOwner.second, channel_platform: ChannelPlatform.last, channel_type: ChannelType.last)
    rec0.save!
    assert_raises(ActiveRecord::RecordNotUnique){ rec1.save!(validate: false) } # DB level
    assert_raises(ActiveRecord::RecordInvalid){   rec1.save! }                  # Rails level
    refute rec1.valid?
  
    %w(owner platform type).each do |metho|
      metho = "channel_"+metho
      metho_w = metho+"="
      rec1.send metho_w, nil
      assert_raises(ActiveRecord::NotNullViolation){rec1.save!(validate: false) } # DB level
      refute rec1.valid?, "#{metho} is null and should be invalid, but..."
      rec1.send metho_w, rec0.send(metho)

      metho_id   = metho+"_id"
      metho_id_w = metho_id + "="
      rec1.send(metho_id_w, metho.camelize.constantize.order(:id).last.id+1)
      assert_raises(ActiveRecord::InvalidForeignKey){rec1.save!(validate: false) } # DB level
      refute rec1.valid?, "#{metho_id} is invalid and should be invalid, but..."
      rec1.send metho_id_w, rec0.send(metho_id)
    end
  end

  test "callbacks" do
    assert_match(/.+\/.+\(.+\)/, Channel.first.def_initial_trans(langcode: "en").title)
    cha = Channel.new(channel_owner: ChannelOwner.first, channel_platform: ChannelPlatform.first, channel_type: ChannelType.first)
    refute cha.valid?
    refute cha.save
    cha.unsaved_translations = cha.def_initial_translations
    assert cha.valid?
    assert cha.save
    cha.reload
    assert_operator 2, :<=, cha.translations.count, "tras = #{cha.translations.inspect}"
  end
end
