class ChangeColumnCommentIdHumanAtPlatformInChannels < ActiveRecord::Migration[7.0]
  def change
    change_column_comment(:channels, :id_human_at_platform, from: "Human-readable Channel-ID at remote without <@>", to: "Human-readable Channel-ID at remote prefixed <@>")
  end
end
