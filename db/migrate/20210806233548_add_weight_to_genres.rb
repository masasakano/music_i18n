class AddWeightToGenres < ActiveRecord::Migration[6.1]
  def change
    add_column :genres, :weight, :float, comment: 'Smaller means higher in priority.'
  end
end
