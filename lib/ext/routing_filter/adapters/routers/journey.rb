# Monkey-patch code for the routing-filter Gem by Dominic Beger at https://makandracards.com/makandra/621175-routing-filter-broken-rails-7-1
if Gem.loaded_specs['routing-filter'].version > Gem::Version.new('0.7')
  raise 'Check if PR https://github.com/svenfuchs/routing-filter/pull/87 has been merged and released. If yes, delete this monkey patch.'
end

# We cannot prepend a custom extension module here because we call `super` in this method which should call the Rails
# #find_routes-method and not the routing_filter's #find_routes-method which is broken.
# Instead, we override the whole module definition to fix it.
module ActionDispatchJourneyRouterWithFiltering

  def find_routes(env)
    path = env.is_a?(Hash) ? env['PATH_INFO'] : env.path_info
    filter_parameters = {}
    original_path = path.dup

    @routes.filters.run(:around_recognize, path, env) do
      filter_parameters
    end

    super(env) do |match, parameters, route|
      parameters = parameters.merge(filter_parameters)

      if env.is_a?(Hash)
        env['PATH_INFO'] = original_path
      else
        env.path_info = original_path
      end

      yield [match, parameters, route]
    end
  end

end
