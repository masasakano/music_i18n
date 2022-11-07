# coding: utf-8
class BaseGrid

  include Datagrid

  # Datagrid enum for the max entries per page for pegination
  MAX_PER_PAGES = {
    10 => 10,
    25 => 25,
    50 => 50,
    100 => 100,
    400 => 400,
    "ALL" => -1,  # -1 is passed to params
  }

  # Absolute maximum limit for pagination.
  HARD_MAX_PER_PAGE = 10000

  # Kaminari default.  I do not know how to get it and so I define it here.
  # @see https://github.com/kaminari/kaminari
  DEF_MAX_PER_PAGE = 25

  # Get the max value
  #
  # @note In terms of the security, it would be marginally better to check with
  #    the allowed values of {MAX_PER_PAGES}. However, since "ALL" is allowed,
  #    there is not much point for that for now.
  #
  # @param nmax [String, NilClass] usually +grid_params[:max_per_page]+ (to permit), where +grid_params+ should be defined in the caller (controller).
  #   nil is allowed — it would be the case when the page is first loaded.
  # @return [Integer] max entries to show per page.
  def self.get_max_per_page(nmax)
    nmax = ((("all" == nmax.downcase) ? HARD_MAX_PER_PAGE : nmax.to_i) rescue DEF_MAX_PER_PAGE)  # if nmax is nil, rescue is called.
    nmax = HARD_MAX_PER_PAGE if nmax < 0 || nmax > HARD_MAX_PER_PAGE
    nmax = DEF_MAX_PER_PAGE  if nmax < 2  # if smaller than 2 (maybe 0 because of String?), something goes wrong.
    nmax
  end

  self.default_column_options = {
    # Uncomment to disable the default order
    # order: false,
    # Uncomment to make all columns HTML by default
    # html: true,
  }
  # Enable forbidden attributes protection
  # self.forbidden_attributes_protection = true

  def self.date_column(name, *args)
    column(name, *args) do |model|
      format(block_given? ? yield : model.send(name)) do |date|
        date ? date.strftime("%Y-%m-%d") : ''
      end
    end
  end
end

#### Does not work: 
## ActionView::Template::Error (no implicit conversion of Regexp into String):
##  Likely here: <%= f.datagrid_label filter %>
#
# # Overwrite separator
# class Datagrid::Filters::BaseFilter
#   def separator
#     options[:multiple].respond_to?('=~') ? options[:multiple] : default_separator
#     # options[:multiple].is_a?(String) ? options[:multiple] : default_separator  # Original
#   end
# end

# @see https://github.com/bogdan/datagrid/wiki/Configuration
Datagrid.configure do |config|

  # Defines date formats that can be used to parse date.
  # Note that multiple formats can be specified but only first format used to format date as string. 
  # Other formats are just used for parsing date from string in case your App uses multiple.
  config.date_formats = ["%Y-%m-%d", "%d/%m/%Y"]

  # Defines timestamp formats that can be used to parse timestamp.
  # Note that multiple formats can be specified but only first format used to format timestamp as string. 
  # Other formats are just used for parsing timestamp from string in case your App uses multiple.
  config.datetime_formats = ["%Y-%m-%d %h:%M:%s", "%d/%m/%Y %h:%M"]
end

