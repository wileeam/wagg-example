class AffinityCalculator

  def self.by_date_range(date_range=Time.now.beginning_of_day..Time.now.end_of_day)

    progress_counter = 0
    affinity = Hash.new { |hash, key| hash[key] = {
        :published_before => {:closeness_pos => 0, :closeness_neg => 0, :closeness_dif => 0 },
        :published_after  => {:closeness_pos => 0, :closeness_neg => 0, :closeness_dif => 0 },
        :queued           => {:closeness_pos => 0, :closeness_neg => 0, :closeness_dif => 0 },
        :discarded        => {:closeness_pos => 0, :closeness_neg => 0, :closeness_dif => 0 }}
    }

    # TODO Pluck instead: news.id, news.status, news.timestamp_creation, news.timestamp_publication
    news = News.complete.votes_complete.where(:timestamp_creation => date_range)
    votes = Vote.joins(:news).merge(news).order(:votable_id => :asc, :voter_id => :asc, :timestamp => :asc)

    news_indexed  = news.index_by(&:id)
    votes_grouped = votes.group_by(&:votable_id) # :votable_id [:vote_1, :vote_2,...:vote_m]

    votes_grouped.each do |news_id, news_votes|
      news_votes_queue = Hash.new

      case news_indexed[news_id].status
        when 'published'
          news_timestamp_publication = news_indexed[news_id].timestamp_publication

          news_votes_before = Array.new
          news_votes_after = Array.new

          news_votes.each do |vote|
            (vote.timestamp < news_timestamp_publication) ? news_votes_before << vote : news_votes_after << vote
          end

          news_votes_queue[:published_before] = news_votes_before
          news_votes_queue[:published_after]  = news_votes_after
        when 'queued', 'discarded'
          news_votes_queue[news_indexed[news_id].status.to_sym] = news_votes
        else
          # TODO Raise exception because this should not be possible
      end

      news_votes_queue.each do |status, votes_list|
        votes_list.each_index do |vote_index|
          vote_minor = votes_list[vote_index]
          ((vote_index + 1)..(votes_list.size - 1)).each do |covote_index|
            vote_major = votes_list[covote_index]
            if vote_minor.rate >= 0 && vote_major.rate >= 0
              affinity[[vote_minor.voter_id, vote_major.voter_id]][status][:closeness_pos] += 1
            elsif vote_minor.rate < 0 && vote_major.rate < 0
              affinity[[vote_minor.voter_id, vote_major.voter_id]][status][:closeness_neg] += 1
            else
              affinity[[vote_minor.voter_id, vote_major.voter_id]][status][:closeness_dif] += 1
            end
          end
        end
      end

      #progress_counter += 1.0
      #if ((progress_counter/news_indexed.size*100).to_i % 10) == 0
      #  puts("Progress: #{(progress_counter/news_indexed.size*100).to_i} %\t(#{progress_counter.to_i}/#{news_indexed.size})")
      #end

    end

    affinity
  end

  def self.sort(affinities=AffinityCalculator.by_date_range)
    affinities.sort_by do |k,v|
      v[:published_before][:closeness_pos] +
          v[:published_before][:closeness_neg] +
          v[:published_before][:closeness_dif] +
      # v[:published_after][:closeness_pos] +
      #     v[:published_after][:closeness_neg] +
      #     v[:published_after][:closeness_dif] +
      v[:queued][:closeness_pos] +
          v[:queued][:closeness_neg] +
          v[:queued][:closeness_dif] +
      v[:discarded][:closeness_pos] +
          v[:discarded][:closeness_neg] +
          v[:discarded][:closeness_dif]
    end
  end

end