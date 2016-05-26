source 'https://rubygems.org'


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '>= 4.2.5'
# Use MySQL as the database for Active Record
# Gem mysql2 does not support jRuby, use activerecord-jdbcmysql-adapter instead
group :production, :development do
  gem 'mysql2', :platform => :ruby
  gem 'activerecord-jdbcmysql-adapter', :platform => :jruby
end
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# Use HAML for views
gem 'haml'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby
# Use DelayedJob for background tasks
gem 'delayed_job_active_record', '>= 4.1.0'
gem 'delayed-web'
# Use Daemons to daemonize the DelayedJob workers
gem 'daemons'
# Some helper for non-sense deadlocks
gem 'transaction_retry'
# Use Whenever to create custom schedules for background scripts
gem 'whenever'
# Use Figaro to use configuration ENV variables
gem 'figaro'

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Temporarily switching to mechanize gem for compability with wagg until mechanize gem is bumped
gem 'mechanize', github: 'sparklemotion/mechanize', ref: 'master'
gem 'wagg', github: 'wileeam/wagg', ref: 'master'

gem 'composite_primary_keys', '~> 8.1.1'
gem 'active_record_union'
gem 'activerecord-import'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  # Gem byebug does not support jRuby
  gem 'byebug', :platform => :ruby

  # Access an IRB console on exception pages or by using <%= console %> in views
  # Requires gem binding_of_caller which does not support jRuby
  gem 'web-console', '~> 2.0', :platform => :ruby

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  # Access to development data easily
  gem 'rails_admin'
end

