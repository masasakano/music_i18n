class EventItems::MatchParentsController < ApplicationController
  before_action :set_event_item, only: [:update]
  load_and_authorize_resource :event_item

  def update
    @event_item.data_to_import_parent.each_pair do |key, val|  # This sets @event_item.warnings
      next if !val
      @event_item.send(key.to_s+"=", val)
    end
    @event_item.warnings.each do |msg|
      add_flash_message(:warning, msg)  # defined in application_controller.rb
    end
    def_respond_to_format(@event_item, :updated){
      @event_item.save
    } # defined in application_controller.rb
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event_item
      @event_item = EventItem.find(params[:id])
      # event_item_params  # (maybe defined below)
    end
end

