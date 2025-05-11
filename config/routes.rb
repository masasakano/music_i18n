Rails.application.routes.draw do
  resources :diagnose, only: [:index]
  resources :urls
  resources :domains
  resources :domain_titles
  resources :site_categories
  resources :channels
  namespace :channels do
    resources :fetch_youtube_channels, only: [:update]  # may add :create in future
  end
  resources :channel_owners
  namespace :channel_owners do
    get 'create_with_artists/new'
  end
  resources :channel_types
  resources :channel_platforms
  resources :harami_vid_music_assocs, only: [:destroy]
  namespace :harami_vid_music_assocs do
    resources :timings, only: [:show, :edit, :update]
    resources :notes,   only: [:show, :edit, :update]
  end
  resources :artist_music_plays, only: [:destroy]
  namespace :artist_music_plays do
    resources :edit_multis, only: [:index, :edit, :update, :create, :show]
  end
  resources :instruments
  resources :play_roles
  resources :event_items
  namespace :event_items do
    resources :deep_duplicates,   only: [:create]
    resources :destroy_with_amps, only: [:destroy]
    resources :resettle_new_events, only: [:update]
  end
  resources :harami1129_reviews
  resources :event_groups
  resources :model_summaries
  namespace :translations do  # "update" is used so that it can be handled with Ability
    get ':id/promotes/update', to: 'promotes#update', as: :update_promotes # => translations_update_promote_path(:id) => /translations/:id/promotes/update
    get ':id/demotes/update',  to: 'demotes#update',  as: :update_demotes  # => translations_update_demote_path(:id)  => /translations/:id/demotes/update
  end
  namespace :artists do
    resources :ac_titles, only: [:index]
    get    ':id/merges/new',  to: 'merges#new',     as: :new_merges  # => artists_new_merge_path(:id)  => /artists/:id/merges/new
    get    ':id/merges/edit', to: 'merges#edit',    as: :edit_merges # => artists_edit_merge_path(:id) => /artists/:id/merges/edit
    match  ':id/merges',      to: 'merges#update',  as: :update_merges, via: [:put, :patch]
    namespace :merges do
      get 'artist_with_ids',   to: 'artist_with_ids#index'  # => artists_merges_artist_with_ids_path => /artists/merges/artist_with_ids#index
    end
  end
  resources :page_formats
  #filter :extension #, :exclude => %r(^admin/)
  filter :locale#,    :exclude => /^\/admin/
  default_url_options(locale: I18n.locale) if Rails.env.test?

  resources :static_pages
  resources :country_masters
  namespace :country_masters do
    post   ':id/create_countries',  to: 'create_countries#update', as: :create_countries  # => country_masters_create_countries_path(:id)  => /country_masters/:id/create_countries
  end

  namespace :musics do
    resources :ac_titles, only: [:index]  # changed from: get 'ac_titles/index'
    get    ':id/merges/new',  to: 'merges#new',     as: :new_merges  # => musics_new_merge_path(:id)  => /musics/:id/merges/new
    get    ':id/merges/edit', to: 'merges#edit',    as: :edit_merges # => musics_edit_merge_path(:id) => /musics/:id/merges/edit
    match  ':id/merges',      to: 'merges#update',  as: :update_merges, via: [:put, :patch]
    resources :upload_music_csvs, only: [:create]
    namespace :merges do
      get 'music_with_ids',   to: 'music_with_ids#index'  # => musics_merges_music_with_ids_path => /musics/merges/music_with_ids#index
    end
  end
  resources :engage_multi_hows, only: [:index, :show, :edit, :create]
  resources :engages, only: [:index, :show, :new, :create, :destroy]
  resources :engage_hows
  #get 'user_role_assoc/update'
  resources :user_role_assoc, only: :update
  namespace :users do
    resources :edit_roles, only: [:update]
    ##resource :confirm, only: :update
    #resources :confirm, only: :update
    match  ':id/confirms', to: 'confirms#update', as: :confirm, via: [:put, :patch]
    get    ':id/deactivate_users/edit', to: 'deactivate_users#edit',    as: :edit_deactivate_users # => users_edit_deactivate_users_path(:id) => /users/:id/deactivate_users/edit
    match  ':id/deactivate_users',      to: 'deactivate_users#update',  as: :do_deactivate_users, via: [:put, :patch]
    delete ':id/deactivate_users',      to: 'deactivate_users#destroy', as: :destroy_deactivate_users  # NOTE: without "as", the prefix would be "users"
  end

  get 'users/index'
  resources :harami1129s
  resources :harami1129s do
    resource :populate,            only: [:update], module: 'harami1129s'
    resource :internal_insertions, only: [:update], module: 'harami1129s'
  end
  namespace :harami1129s do
    resource :download_harami1129s, only: [:new]
    resource :inject_from_harami1129s, only: [:create]
    post     :internal_insertions, to: 'internal_insertions#update_all'
    #patch     :internal_insertions, to: 'internal_insertions#update_all'
    #put       :internal_insertions, to: 'internal_insertions#update_all'  # Patch and Put does not work: Rails.application.routes.recognize_path("/harami1129s/internal_insertions", method: :put) #=> {:controller=>"harami1129s", :action=>"update", :id=>"internal_insertions"}
  end
  namespace :harami_vids do
    resources :fetch_youtube_data, only: [:create, :update]
    resources :update_places,      only: [:show,   :update]
    resources :add_missing_music_to_evits, only: [:show,   :update]
  end
  resources :genres
  resources :translations
  resources :places
  resources :prefectures
  resources :countries
  resources :roles
  resources :role_categories
  resources :sexes

  ## WARNING: It seems the following MUST come after namespace definitions (of :artists and :musics, specifically).  Otherwise, auto-completion would not work...
  %w(artists events harami_vids musics places).each do |model_plural|
    resources model_plural.to_sym do
      resources :anchorings, controller: model_plural+'/anchorings'
    end
  end

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  # devise_for :users  # Default
  devise_for :users, :except => [:destroy]
  # devise_for :users, :path_prefix => 'd'  # => /usrs/d/sign_up etc
  resources :users, :only =>[:show]
  #match '/users/:id',     to: 'users#show',       via: 'get'
  #match '/users/:id',     to: 'users#show',  :as => :user,     via: 'get'
  root to: "home#index"
  get 'home/index'

  match '/users',   to: 'users#index',   via: 'get'
  ##resources :users do
  ##  resource :user_lists, only: [:index], module: 'users'
  ##end
  #namespace :users do
  #  get      :user_lists, only: [:index], to: 'user_lists#index'
  #  post     :user_lists, only: [:index], to: 'user_lists#index'
  #end

  # Arbitrary page paths are dealt with StaticPagePublicsController
  get '/static_page_publics', to: 'static_page_publics#index'
  constraints(lambda { |request| !File.basename(request.fullpath).sub(/\?.*/, '').include?('.') }) do
    # Except the filenames with a suffix like .jpg or even .html
    get '*path', to: 'static_page_publics#show'
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
