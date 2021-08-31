class BaseGrid

  include Datagrid

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

