# == Schema Information
#
# Table name: engage_hows
#
#  id         :bigint           not null, primary key
#  note       :text
#  weight     :float            default(999.0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class EngageHowTest < ActiveSupport::TestCase
  test "fixtures" do
    def_eh = EngageHow.default(:HaramiVid)
    assert_match(/\boriginal\b/i, def_eh.title(langcode: "en"))
    assert_match(/\bsinger\b/i,   def_eh.title(langcode: "en"))
  end

  test "on_delete dependency" do
    eh1 = engage_hows( :engage_how_1 )
    assert_raises(ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey){ eh1.destroy } # DRb::DRbRemoteError: PG::ForeignKeyViolation: ERROR:  update or delete on table "engage_hows" violates foreign key constraint "fk_rails_0a84c2f7e6" on table "engages" DETAIL:  Key (id)=(949583562) is still referenced from table "engages".  # => ActiveRecord::DeleteRestrictionError (by Rail's validation)

    #eh1.destroy
    #assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid){ eh1.destroy }
    # DRb::DRbRemoteError: PG::CheckViolation: ERROR:  new row for relation "artists" violates check constraint "check_artists_on_birth_month"
  end

  test "unknown" do
    assert EngageHow.unknown
    assert_operator 0, '<', EngageHow.unknown.id
    obj = EngageHow[/UnknownEng/i, 'en']
    assert_equal obj, EngageHow.unknown
    assert obj.unknown?
  end

  test "translation uniqueness" do
    # All the title-s and alt_title-s in EngageHow must be unique within a language.
    # Defined in validate_translation_callback() in engage_how.rb
    assert_raises(ActiveRecord::RecordInvalid){ 
      engage_hows(:engage_how_composer).with_translation(langcode: 'en', title: 'new3',
        alt_title: engage_hows(:engage_how_player).title(langcode: 'en'), is_orig: false) }

    # But words can be the same in separate languages.
    assert_nothing_raised{ 
      engage_hows(:engage_how_composer).with_translation(langcode: 'fr', title: 'new3',
        alt_title: engage_hows(:engage_how_player).title(langcode: 'en'), is_orig: false) }
  end

  test "weight value" do
    eh = EngageHow.new
    assert eh.valid?  # Due to the presence of the DB Default weight, it is valid.

    eh_unk = EngageHow.unknown
    eh1    = EngageHow.where('id <> ?', eh_unk.id).first
    assert_operator eh1, '<', eh_unk
  end
end
