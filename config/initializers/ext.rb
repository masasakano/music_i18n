# As recommended in https://makandracards.com/makandra/621175-routing-filter-broken-rails-7-1
Dir.glob(Rails.root.join('lib/ext/**/*.rb')).sort.each do |filename|
 require filename
end
