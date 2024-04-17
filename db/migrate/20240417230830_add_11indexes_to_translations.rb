class Add11indexesToTranslations < ActiveRecord::Migration[7.0]
  def change
    add_index :translations, :translatable_type
    add_index :translations, :translatable_id  
    add_index :translations, :langcode         
    add_index :translations, :title            
    add_index :translations, :alt_title        
    add_index :translations, :ruby             
    add_index :translations, :alt_ruby         
    add_index :translations, :romaji           
    add_index :translations, :alt_romaji       
    add_index :translations, :is_orig          
    add_index :translations, :weight           
  end
end
