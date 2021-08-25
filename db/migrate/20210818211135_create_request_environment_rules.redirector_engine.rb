# This migration comes from redirector_engine (originally 20120823163756)
class CreateRequestEnvironmentRules < ActiveRecord::Migration[4.2]
  def change
    create_table :request_environment_rules do |t|
      t.integer :redirect_rule_id, :null => false
      t.string :environment_key_name, :null => false, comment: 'Name of the enviornment key (e.g. "QUERY_STRING", "HTTP_HOST")'
      t.string :environment_value, :null => false, comment: 'What to match the value of the specified environment attribute against'
      t.boolean :environment_value_is_regex, :null => false, :default => false, comment: 'Is the value match a regex or not'
      t.boolean :environment_value_is_case_sensitive, :null => false, :default => true, comment: 'is the value regex case sensitive or not'
      t.timestamps
    end
    add_index :request_environment_rules, :redirect_rule_id
  end
end

