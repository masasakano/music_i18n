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

