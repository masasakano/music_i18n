# This migration comes from redirector_engine (originally 20120815212612)
class CreateRedirectRules < ActiveRecord::Migration[4.2]
  def change
    create_table :redirect_rules do |t|
      t.string :source, :null => false, comment: 'Matched against the request path'
      t.boolean :source_is_regex, :null => false, :default => false, comment: 'Is the source a regular expression or not'
      t.boolean :source_is_case_sensitive, :null => false, :default => false, comment: 'Is the source regex cas sensitive or not'
      t.string :destination, :null => false
      t.boolean :active, :default => false, comment: 'Should this rule be applied or not'
      t.timestamps
    end
    add_index :redirect_rules, :source
    add_index :redirect_rules, :active
    add_index :redirect_rules, :source_is_regex
    add_index :redirect_rules, :source_is_case_sensitive
  end
end

