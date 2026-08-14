module StimulusHelper
  # Wrappe of +tag+ method to present a DIV block watched by a Stimulus Controller
  #
  # @example
  #   <%= stimulus_controller_block("cascadingSelect",
  #                                  values: {select_name: my_param_name(:event_id), required: false},
  #                                  actions: "keydown.esc@window->dropdown#close",
  #                                  data: {something_extra: nil},
  #                                  style: "color: red;") do %>
  #     <p>Something...</p>
  #   <% end %> <%# defined in stimulus_helper.rb %>
  #     # =>
  #     # <div data-controller="cascading-select" 
  #     #      data-cascading-select-select-name-value="article[event_id]"
  #     #      data-cascading-select-required-value="false"
  #     #      data-something-extra=""
  #     #      style="color: red;">
  #     #   <p>Something...</p>
  #     # </div>
  #
  # @param controller_name [String] Stimulus Controller name in any form (lowerCamelCase, snake_case, kebab-case)
  # @param values: [Hash] Values to passed to Stimulus Controller
  # @param actions: [Array, String] Action name, e.g., "change->cascading-select#update"
  # @param data: [Hash]
  # @param tagname: [String] +<div>+ in default
  # @param **html_options [Hash] passed to +tag+
  def stimulus_controller_block(controller_name, *args, values: {}, actions: [], data: {}, tagname: "div", **html_options, &block)
    kebab_controller_name = controller_name.to_s.underscore.dasherize

    # 1. Add controller name, e.g., data-controller="cascading-select"
    data[:controller] = [data[:controller], kebab_controller_name].compact.join(" ")

    # 2. Map values: { url_template: "..." } -> data-cascading-select-url-template-value="..."
    values.each do |key, val|
      data["#{kebab_controller_name}-#{key.to_s.underscore.dasherize}-value"] = val
    end

    # 3. Map actions: ["change->cascading-select#update"] -> data-action="..."
    if actions.present?
      data[:action] = [data[:action], Array(actions).join(" ")].compact.join(" ")
    end

    tag.public_send(tagname, *args, data: data, **html_options, &block)
  end
end

