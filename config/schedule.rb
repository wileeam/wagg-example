# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end
# Learn more: http://github.com/javan/whenever

#TODO
# At 4am, 4pm, 8pm, 12am, 2.30am
# run negative votes (if news exists do NOT consider comments in case news is closed)
# At 10am
# run update closed news (go for news itself and comments, do NOT consider votes)

every '0 0,3,4,18 * * *' do
  runner "Maintainer::Updater.latest_submitted_news", :environment => 'development'
end

every '30 22,2 * * *' do
  rake "maintenance:news:update_votes", :environment => 'development'
end