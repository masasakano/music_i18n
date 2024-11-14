# -*- coding: utf-8 -*-

# Common module for Controllers that uses DataGrid
#
# @example Music
#   include ModuleGridController # for set_grid
#   def index
#     set_grid(Music)  # setting @grid; defined in concerns/module_grid_controller.rb
#   end
#
# == NOTE
#
module ModuleGridController
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  include ApplicationHelper

  #module ClassMethods
  #end

  # sets @grid
  #
  # @example Artist. n.b., break (as opposed to next) would raise "ActionView::Template::Error: break from proc-closure"
  #   set_grid(Artist){ |scope, grid_prms|
  #     next scope if grid_params[:order].present?
  #     harami = Artist.default(:HaramiVid)
  #     scope.order(Arel.sql("CASE artists.id WHEN #{harami.id rescue 0} THEN 0 ELSE 1 END, created_at DESC"))
  #   }  # setting @grid; defined in concerns/module_grid_controller.rb
  #
  # @example HaramiVid
  #   set_grid(HaramiVid, hs_def: {order: :release_date, descending: true})  # setting @grid; defined in concerns/module_grid_controller.rb
  #
  # @param model [Class, ApplicationRecord, String, Symbol]
  # @param hs_def: [Hash] to give @grid in default
  # @return [Google::Apis::YoutubeV3::YouTubeService]
  def set_grid(model, hs_def: {})
    prm_name = plural_underscore(model) + "_grid"  # e.g., "artists_grid"; defined in application_helper.rb
    grid_klass = prm_name.classify.constantize

    grid_prms = (params[prm_name] || {})  # NULL for the first-time access to index
    grid_prms = grid_prms.merge(hs_def) if hs_def.present?

    @grid = grid_klass.new(grid_prms) do |scope|
      nmax = ApplicationGrid.get_max_per_page(grid_prms[:max_per_page])
      if block_given?
        scope = (yield(scope, grid_prms) || scope)
      end
      scope.page(params[:page]).per(nmax)
    end
  end


  #################
  private 
  #################

end
