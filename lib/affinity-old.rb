#!/usr/bin/env ruby

APP_PATH = File.expand_path('../../config/application',  __FILE__)
require File.expand_path('../../config/boot',  __FILE__)
require APP_PATH
# set Rails.env here if desired
Rails.application.require_environment!


begin_date  = 6.months.ago.beginning_of_month
end_date    = begin_date.end_of_month
interval    = 1.week

news_list = News.joins(:votes).where(:timestamp_creation => begin_date..end_date).where(:news => {:status => 'published'}).group(:id).having('count(*) = (news.votes_count_positive + news.votes_count_negative)')
voters_list = Vote.joins(:news).where(:news => news_list.collect(&:id)).uniq.pluck(:voter_id)
voters_affinity = Hash[voters_list.map {|v| [v,nil]}]

news_list.each do |news|
  news_votes = news.votes.order(:voter_id)
  news_votes_set = news_votes.to_set

  news_votes.each do |vote|
    voters_affinity[vote.voter_id] = Hash.new(0) if voters_affinity[vote.voter_id].nil?

    news_votes_set.delete(vote)
    news_votes_set.each do |vote_pair|
      voters_affinity[vote.voter_id][vote_pair.voter_id] += 1
    end
  end
end

# TODO Clean up table here?

voters_affinity.each do |minor_voter, affinities|
  affinities_list = Array.new
  # voters_affinity[minor_voter] = affinities
  affinities.each do |major_voter, affinity_closeness|
    #affinity = Affinity.find_or_initialize_by(:minor_id => minor_voter, :major_id => major_voter) do |a|
    #  a.closeness = 0
    #end
    #affinity.closeness += affinity_closeness
    #affinities_list << affinity
    affinities_list << "(%{min}, %{maj}, %{c}, NULL, NOW(), NOW())" %{min:minor_voter, maj:major_voter, c:affinity_closeness}
  end
  unless affinities_list.empty?
    sql = "INSERT INTO affinities (minor_id, major_id, closeness , weighted_closeness, created_at, updated_at) VALUES #{affinities_list.join(", ")}"
    ActiveRecord::Base.connection.execute(sql)
  end
end
