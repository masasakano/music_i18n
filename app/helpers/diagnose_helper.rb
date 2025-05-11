module DiagnoseHelper
  # @example
  #    <%= print_warning_or_normal(reasons, "no_engages") do %>
  #      <%= record.engages.count %>
  #    <% end %>
  #
  # @yield block to print out if there is no warning.
  def print_warning_or_normal(reasons, key, red_word: "NONE")
    if reasons.include? key
      return sprintf('<span class="text-warning-regular">%s</span>', sanitize(red_word)).html_safe
    elsif block_given?
      capture{ yield }
    end
  end
end
