# coding: utf-8
class AddChannelToHaramiVids < ActiveRecord::Migration[7.0]
  class Channel < ApplicationRecord
    has_many :translations, as: :translatable, dependent: :destroy
  end
  class Translation < ApplicationRecord
    belongs_to :translatable, polymorphic: true
  end
  class ChannelOwner < ApplicationRecord
    has_many :translations, as: :translatable, dependent: :destroy
  end
  class ChannelType < ApplicationRecord
    has_many :translations, as: :translatable, dependent: :destroy
  end
  class ChannelPlatform < ApplicationRecord
    has_many :translations, as: :translatable, dependent: :destroy
  end

  def change
    # HaramiVid should have Channel - but migration with "null: false" would fail and so it is allowed to be nil at the moment.
    # A Channel with children cannot be destroyed easily.
    add_reference :harami_vids, :channel, null: true, foreign_key: true
    reversible do |direction|
      direction.up do
        arret = _create_basic_channels
        puts "-- Created #{arret.join(' and ')}" if !arret.empty?
      end
    end
  end

  # @return [Array<String>] newly Created files
  def _create_basic_channels
    arret = []
    arret.push("Channel.unknown") if _create_basic_channel_unknown
    result, cpr = _create_basic_channel_harami  # cpr - Channel-PRimary
    arret.push("Channel.primary") if result
    cpr.reload
    HaramiVid.update_all(channel_id: cpr.id)  # updated_at is not updated.
    arret
  end

  # Creates Channel.unknown if not yet created.
  # @return [NilClass, TrueClass] nil if nothing is updated. true if newly created
  def _create_basic_channel_unknown
    unknowns = {}.with_indifferent_access
    unknowns[:owner] = (Object::Channel.unknown rescue nil)
    return if unknowns[:owner]

    unknowns.merge!({
      type: ChannelType.find_by(mname: "unknown"),
      platform: ChannelPlatform.find_by(mname: "unknown")
    }.with_indifferent_access)
    unknowns[:owner] = (Object::ChannelOwner.unknown rescue nil)
    unknowns[:owner] ||= (ChannelOwner.find(Translation.where("regexp_match(translations.title, '^unknown ?channel ?owner', 'in') IS NOT NULL").where(translatable_type: 'ChannelOwner').first.translatable_id) rescue nil)
    raise "ChannelOwner.unknown cannot be found." if !unknowns[:owner]
    unknowns[:channel] = Channel.find_or_initialize_by(
      channel_type_id: unknowns[:type].id,
      channel_platform_id: unknowns[:platform].id,
      channel_owner_id: unknowns[:owner].id,
    )

    return nil if !unknowns[:channel].new_record? 
    unknowns[:channel].save!

    titles = (Object::Channel::UNKNOWN_TITLES rescue nil)
    titles ||= {
      "ja" => ['不明のチャンネル'],
      "en" => ['Unknown channel'],
      "fr" => ['Chaine inconnue'],
    }.with_indifferent_access

    titles.each_pair do |ek, ev|
      tra = Translation.new(
        title: ev.first,
        langcode: ek,
        is_orig: nil,
        weight: 0
      )
      unknowns[:channel].translations << tra
      tra.reload.update!(translatable_type: "Channel")  # originally, "AddChannelToHaramiVids::Channel"
    end
    return true
  end

  # Creates Channel.primary if not yet created.
  # @return [Array<NilClass|TrueClass, Channel] the first one nil if nothing is updated. Second one is {Channel.primary}.
  def _create_basic_channel_harami
    obj = _get_primary_of_class(Channel)
    return [nil, obj] if obj.respond_to? :translations

    ch_harami = Channel.find_or_initialize_by(
      channel_type_id:     ChannelType.find_by(mname: :main).id,
      channel_platform_id: ChannelPlatform.find_by(mname: :youtube).id,
      channel_owner_id: _get_primary_of_class(ChannelOwner).id,
    )

    return [nil, ch_harami] if !ch_harami.new_record? 
    ch_harami.save!

    obj.each_value do |ev|
      tra = Translation.new(ev)
      ch_harami.translations << tra 
      tra.reload.update!(translatable_type: "Channel")  # originally, "AddChannelToHaramiVids::Channel"
    end
    return [true, ch_harami]
  end

  # @see /app/models/concerns/module_primary_artist.rb
  #
  # @param klass [Class] sub-Class of this Migration class with the same name of ActiveRecord
  # @return [ActiveRecord, Hash] Hash is returned if the primary ActiveRecord is not found.
  #    Hash has keys of langcodes with values of hashes to feed to {Translation.new}
  def _get_primary_of_class(klass)
    hstra = {}.with_indifferent_access
    class_name = klass.name.split("::").last
    ch_harami = (Object.const_get(class_name).primary rescue nil)
    return ch_harami if ch_harami

    %w(ja en).each do |lc|
      hstra[lc] = {}.with_indifferent_access
      %w(weight is_orig langcode).each do |ec|
        hstra[lc][ec] = Rails.application.config.primary_artist_titles[lc][ec]
      end
      %w(title alt_title ruby romaji).each do |ec|
        hstra[lc][ec] = Rails.application.config.primary_artist_titles[lc][ec]
        next if hstra[lc][ec].blank?
        ch_harami ||= (Channel.find(Translation.where(ec => hstra[lc][ec]).where(translatable_type: class_name).first.translatable_id) rescue nil)
      end
    end
    return ch_harami if ch_harami
    hstra
  end
end
