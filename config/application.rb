require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WaggExample
  class Application < Rails::Application
    config.assets.precompile << 'delayed/web/application.css'
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.autoload_paths << Rails.root.join('app/jobs')

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Set the queuing system to delayed_job gem
    config.active_job.queue_adapter = :delayed_job
  end

  # App constants
  PAGE_BATCH_SIZE = 5

  JOB_QUEUE = Hash.new
  JOB_QUEUE['author'] = 'authors'
  JOB_QUEUE['news'] = 'news'
  JOB_QUEUE['comment'] = 'comments'
  JOB_QUEUE['vote'] = 'votes'
  JOB_QUEUE['voting_list'] = 'voting_lists'

  JOB_QUEUE['authors'] = JOB_QUEUE['author']
  JOB_QUEUE['comments'] = JOB_QUEUE['comment']
  JOB_QUEUE['votes'] = JOB_QUEUE['vote']
  JOB_QUEUE['voting_lists'] = JOB_QUEUE['voting_list']


  JOB_PRIORITY = Hash.new
  JOB_PRIORITY['author'] = 1
  JOB_PRIORITY['news'] = 10
  JOB_PRIORITY['comment'] = 9
  JOB_PRIORITY['vote'] = 5
  JOB_PRIORITY['voting_list'] = 4

  JOB_PRIORITY['authors'] = JOB_PRIORITY['author']
  JOB_PRIORITY['comments'] = JOB_PRIORITY['comment']
  JOB_PRIORITY['votes'] = JOB_PRIORITY['vote']
  JOB_PRIORITY['voting_lists'] = JOB_PRIORITY['voting_list']
end
