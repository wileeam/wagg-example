Rails.application.routes.draw do

  mount RailsAdmin::Engine => '/admin',     as: 'rails_admin'

  # Delayed Jobs
  mount Delayed::Web::Engine,               at: '/jobs'

  # Show options to retrieve data
  get 'retrieve',                           to: 'retrieve#index'
  # Retrieve specific pages, intervals or all
  get 'retrieve/page',                      to: 'retrieve#page'
  get 'retrieve/page/:index',                  to: 'retrieve#page_single'
  get 'retrieve/page/:init_index/to/:end_index',  to: 'retrieve#page_interval'
  get 'retrieve/page/all',                  to: 'retrieve#page'

  # Retrieve specific news or intervals or all
  get 'retrieve/news',                      to: 'retrieve#news'
  get 'retrieve/news/votes',                to: 'retrieve#news_votes'
  get 'retrieve/news/:id',                  to: 'retrieve#news'
  get 'retrieve/news/:init_id/to/:end_id',  to: 'retrieve#news_interval'
  get 'retrieve/news/all',                  to: 'retrieve#all_news'

  get 'retrieve/comment',                   to: 'retrieve#comment'
  get 'retrieve/comment/votes',             to: 'retrieve#comment_votes'
  get 'retrieve/comment/:id',               to: 'retrieve#comment'
  get 'retrieve/comment/all',               to: 'retrieve#all_comments'
  get 'retrieve/comments/:id',              to: 'retrieve#comments'

  get 'retrieve/vote',                      to: 'retrieve#vote'
  get 'retrieve/vote/all',                  to: 'retrieve#votes'

  get 'update',                             to: 'update#index'
  #get 'update/all',                         to: 'update#index'
  get 'update/news',                        to: 'update#news'
  #get 'update/news/all',                    to: 'update#news'
  get 'update/comment/:id',                 to: 'update#comment'
  get 'update/comments',                    to: 'update#comments'
  #get 'update/comments/all',                to: 'update#comments'


  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
