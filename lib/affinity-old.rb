#!/usr/bin/env ruby

APP_PATH = File.expand_path('../../config/application',  __FILE__)
require File.expand_path('../../config/boot',  __FILE__)
require APP_PATH
# set Rails.env here if desired
Rails.application.require_environment!


begin_date  = 3.months.ago.beginning_of_month
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

# voters_affinity.each do |minor_voter, affinities|
#   affinities_list = Array.new
#   # voters_affinity[minor_voter] = affinities
#   affinities.each do |major_voter, affinity_closeness|
#     #affinity = Affinity.find_or_initialize_by(:minor_id => minor_voter, :major_id => major_voter) do |a|
#     #  a.closeness = 0
#     #end
#     #affinity.closeness += affinity_closeness
#     #affinities_list << affinity
#     affinities_list << "(%{min}, %{maj}, %{c}, NULL, NOW(), NOW())" %{min:minor_voter, maj:major_voter, c:affinity_closeness}
#   end
#   unless affinities_list.empty?
#     sql = "INSERT INTO affinities (minor_id, major_id, closeness , weighted_closeness, created_at, updated_at) VALUES #{affinities_list.join(", ")}"
#     ActiveRecord::Base.connection.execute(sql)
#   end
# end

class Node

  attr_accessor :identifier

  def initialize(identifier)
    @identifier = identifier
  end

  def to_s
    @identifier.to_s
  end

end

class Edge
  include Comparable

  attr_accessor :minor, :major
  attr_accessor :weight

  def initialize(minor, major, weight)
    @minor = minor
    @major = major
    @weight = weight
  end

  def <=>(anOther)
    @weight <=> anOther.weight
  end

  def to_s
    "(%{mi} - %{ma}) :: %{w}" %{mi:@minor.to_s, ma:@major.to_s, w:@weight.to_s}
  end

end

edges_list = Array.new

voters_affinity.each do |minor_voter, affinities|
  minor_node = Node.new(minor_voter)
  affinities.each do |major_voter, affinity_closeness|
    major_node = Node.new(major_voter)
    affinity_edge = Edge.new(minor_node, major_node, affinity_closeness)
    edges_list << affinity_edge
  end
end

list = edges_list.sort; nil
sorted_edges_list = list.reverse; nil