Rails.application.routes.draw do
  resources :page_formats
  #filter :extension #, :exclude => %r(^admin/)
  filter :locale#,    :exclude => /^\/admin/
  default_url_options(locale: I18n.locale) if Rails.env.test?

  resources :static_pages
  resources :country_masters
  namespace :musics do
    resources :upload_music_csvs, only: [:create]
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
  resources :harami_vids
  resources :harami1129s
  resources :musics
  resources :genres
  resources :artists
  resources :translations
  resources :places
  resources :prefectures
  resources :countries
  resources :roles
  resources :role_categories
  resources :sexes

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
