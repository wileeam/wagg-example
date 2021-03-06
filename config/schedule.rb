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

# Scrap new news since last scrap (see maintenance:comments:scrap_latest for 14:00)
every '0 0,3,4,18,20 * * *' do
  rake "maintenance:news:scrap_latest",           :environment  =>  'development'
end

every '30 22,2,3 * * *' do
  rake "maintenance:news:update_votes",           :environment  =>  'development'
end

every :day, :at => '5am' do
  rake "maintenance:news:complete",               :environment  =>  'development'
end

every :day, :at => '8am' do
  rake "maintenance:news:check_consistency",      :environment  =>  'development'
end

# Scrap new comments of open news since last scrap (note the script does a news scrap as well)
every :day, :at => '2pm' do
  rake "maintenance:comments:scrap_latest",       :environment  =>  'development'
end

every :day, :at => '7am' do
  rake "maintenance:comments:update_votes",       :environment  =>  'development'
end

every :day, :at => '10am' do
  rake "maintenance:comments:complete",           :environment  =>  'development'
end

every :day, :at => '12pm' do
  rake "maintenance:comments:check_consistency",  :environment  =>  'development'
end
