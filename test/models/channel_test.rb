# == Schema Information
#
# Table name: channels
#
#  id                  :bigint           not null, primary key
#  note                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  channel_owner_id    :bigint           not null
#  channel_platform_id :bigint           not null
#  channel_type_id     :bigint           not null
#  create_user_id      :bigint
#  update_user_id      :bigint
#
# Indexes
#
#  index_channels_on_channel_owner_id     (channel_owner_id)
#  index_channels_on_channel_platform_id  (channel_platform_id)
#  index_channels_on_channel_type_id      (channel_type_id)
#  index_channels_on_create_user_id       (create_user_id)
#  index_channels_on_update_user_id       (update_user_id)
#  index_unique_all3                      (channel_owner_id,channel_type_id,channel_platform_id) UNIQUE
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
