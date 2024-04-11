class CreateInstruments < ActiveRecord::Migration[7.0]
  def change
    tit = "(Music) Instruments for ArtistMusicPlay to go with PlayRole"
    create_table :instruments, comment: tit do |t|
      t.float :weight, null: false, default: 999.0, index: true, comment: "weight for sorting for index."
      t.text :note

      t.timestamps
    end

    change_table_comment(:instruments, from: "", to: tit)
    tit = "(Music) Instruments for ArtistMusicPlay to go with PlayRole"
  end
end
