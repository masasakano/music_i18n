class AddCommitMessageToVersions < ActiveRecord::Migration[6.1]
  def change
    add_column :versions, :commit_message, :text, comment: 'user-added meta data'
  end
end
