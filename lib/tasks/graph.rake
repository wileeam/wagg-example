namespace :graph do
  desc "Calculates the affinity between voters"
  task :affinity, [:initial_date, :weeks]  => [:environment] do |t, args|
    args.with_defaults(:initial_date => 3.months.ago, :weeks => 4)

    begin_week = args[:initial_date].to_i.beginning_of_week
    weeks = args[:weeks].to_i

    end_week = begin_week.end_of_week

    weeks.times do

      news_list = News.joins(:votes).where(:timestamp_creation => begin_week..end_week).where(:news => {:status => 'published'}).group(:id).having('count(*) = (news.votes_count_positive + news.votes_count_negative)')
      voters_list = Vote.joins(:news).where(:news => news_list.collect(&:id)).uniq.pluck(:voter_id)
      voters_affinity = Hash[voters_list.map {|v| [v,nil]}]

    end

  end

  desc "TODO"
  task :no_weeks, [:threads]  => [:environment] do |t, args|
    args.with_defaults(:threads => 10)

    threads_size = args[:threads].to_i

    # class Node
    #
    #   attr_accessor :identifier
    #
    #   def initialize(identifier)
    #     @identifier = identifier
    #   end
    #
    #   def to_s
    #     @identifier.to_s
    #   end
    #
    # end
    #
    # class Edge
    #   #include Comparable
    #
    #   attr_accessor :minor, :major
    #   attr_accessor :weight
    #
    #   def initialize(minor, major, weight)
    #     @minor = minor
    #     @major = major
    #     @weight = Hash.new
    #     @weight['+='] = weight['+=']
    #     @weight['-='] = weight['-=']
    #     @weight['<>'] = weight['<>']
    #   end
    #
    #   #def <=>(anOther)
    #   #  (@weight['+='] + @weight['-='] + @weight['<>']) <=> (anOther.weight['+='] + anOther.weight['-='] + anOther.weight['<>'])
    #   #end
    #
    #   def to_s
    #     "(%{mi} - %{ma}) :: %{w}" %{mi:@minor.to_s, ma:@major.to_s, w:@weight.to_s}
    #   end
    #
    # end

    week_range = News.complete.votes_complete.minimum(:timestamp_creation).all_week

    # TODO Not entirely true, there may be weeks with no news... right?
    while (news_list = News.complete.votes_complete.where(:timestamp_creation => week_range).order(:timestamp_creation => :asc)).size > 0

      # Rails.logger   " => #{Time.now} Calculating affinities :: START"
      # voters_list = Vote.joins(:news).where(:news => news_list.collect(&:id)).uniq.pluck(:voter_id)
      # voters_affinity = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = {'+=' => 0, '-=' => 0, '<>' => 0} } }
      # voters_affinity = Hash.new { |hash, key| hash[key] = {'+=' => 0, '-=' => 0, '<>' => 0} }
      voters_affinity = Hash.new { |hash, key| hash[key] = {:published_before => {'+=' => 0, '-=' => 0, '<>' => 0},
                                                            :published_after  => {'+=' => 0, '-=' => 0, '<>' => 0},
                                                            :queued           => {'+=' => 0, '-=' => 0, '<>' => 0},
                                                            :discarded        => {'+=' => 0, '-=' => 0, '<>' => 0}
                                                           }
                                 }

      # Rails.logger   " => #{Time.now}   Querying for affinities :: START"

      # sql = "SELECT `v1`.`votable_id` AS `id`, `v1`.`voter_id` AS `minor`, `v1`.`rate` AS `minor_rate`, `v1`.`weight` AS `minor_weight`, `v1`.`timestamp` AS `minor_timestamp`, `v2`.`voter_id` AS `major`, `v2`.`rate` AS `major_rate`, `v2`.`weight` AS `major_weight`, `v2`.`timestamp` AS `major_timestamp`"
      # sql += " FROM  votes v1, votes v2, `news`"
      # sql += " WHERE `v1`.`votable_id` = `news`.`id` AND `v1`.`votable_id` = `v2`.`votable_id` AND `v1`.`votable_type` = 'News' AND `v1`.`voter_id` != `v2`.`voter_id` AND `v1`.`voter_id` < `v2`.`voter_id` AND `news`.`complete` = 1 AND (`news`.`timestamp_creation` BETWEEN '#{week_range.begin}' AND '#{week_range.end}')"
      # sql += " ORDER BY `v1`.`voter_id` ASC, `v2`.`voter_id` ASC"
      # vote_pairs_list = ActiveRecord::Base.connection.exec_query(sql)

      votes_list = Vote.joins(:news).where(:news => {:timestamp_creation => week_range.begin..week_range.end}).order(:votable_id => :asc, :voter_id => :asc)
      # Rails.logger   " => #{Time.now}   Querying for affinities :: END"

      # vote_pairs_list.each(:as => :hash) do |vote_pair|
      #   if vote_pair['minor_rate'] >= 0 && vote_pair['major_rate'] >= 0
      #     voters_affinity[vote_pair['minor']][vote_pair['major']]['+='] = voters_affinity[vote_pair['minor']][vote_pair['major']]['+='] + 1
      #   elsif vote_pair['minor_rate'] < 0 && vote_pair['major_rate'] < 0
      #     voters_affinity[vote_pair['minor']][vote_pair['major']]['-='] = voters_affinity[vote_pair['minor']][vote_pair['major']]['-='] + 1
      #   else # vote_pair['minor_rate'] >= 0 && vote_pair['major_rate'] < 0 || vote_pair['minor_rate'] < 0 && vote_pair['major_rate'] >= 0
      #     voters_affinity[vote_pair['minor']][vote_pair['major']]['<>'] = voters_affinity[vote_pair['minor']][vote_pair['major']]['<>'] + 1
      #   end
      # end

      ## TODO: Describe the technique
      mutex = Mutex.new
      threads = Array.new
      votes_list_grouped = votes_list.group_by(&:votable_id)
      #votes_list_grouped.each do |votable_id, votes_news_list|
      votes_list_grouped.keys.each_slice([votes_list_grouped.keys.size/threads_size, 1].max).each do |votable_id_list_slice|
        threads << Thread.new(votable_id_list_slice) do |votable_id_list|
          local_voters_affinity = Hash.new { |hash, key| hash[key] = {:published_before => {'+=' => 0, '-=' => 0, '<>' => 0},
                                                                      :published_after  => {'+=' => 0, '-=' => 0, '<>' => 0},
                                                                      :queued           => {'+=' => 0, '-=' => 0, '<>' => 0},
                                                                      :discarded        => {'+=' => 0, '-=' => 0, '<>' => 0}
                                                                     }
                                           }
          votable_id_list.each do |votable_id|
            news_status = news_list.index_by(&:id)[votable_id].status
            votes_news_list = votes_list_grouped[votable_id]
            if news_status != 'published' # news_status == 'queued' || news_status == 'discarded'
              votes_news_list.each_index do |index_vote|
                vote = votes_news_list[index_vote]
                ((index_vote + 1)..(votes_news_list.size - 1)).each do |index_covote|
                  covote = votes_news_list[index_covote]
                  if vote.rate >= 0 && covote.rate >= 0
                    local_voters_affinity[[vote.voter_id, covote.voter_id]][news_status.to_sym]['+='] += 1
                  elsif vote.rate < 0 && covote.rate < 0
                    local_voters_affinity[[vote.voter_id, covote.voter_id]][news_status.to_sym]['-='] += 1
                  else # vote['minor_rate'] >= 0 && covote['major_rate'] < 0 || vote['minor_rate'] < 0 && covote['major_rate'] >= 0
                    local_voters_affinity[[vote.voter_id, covote.voter_id]][news_status.to_sym]['<>'] += 1
                  end
                end
              end
            else # news_status == 'published'
              # Rails.logger   " => #{Time.now}     Processing affinities for published news :: START"
              votes_published_news_list = { :published_before => Array.new, :published_after => Array.new }
              news_timestamp_publication = news_list.index_by(&:id)[votable_id].timestamp_publication

              # Rails.logger   " => #{Time.now}       Splitting votes on timestamp_publication  :: START"
              votes_news_list.each do |vote|
                (vote.timestamp < news_timestamp_publication) ?
                    votes_published_news_list[:published_before] << vote :
                    votes_published_news_list[:published_after] << vote
              end
              # TODO Sorting is not needed I think...
              votes_published_news_list[:published_before].sort_by! { |vote| vote.voter_id }
              votes_published_news_list[:published_after].sort_by! { |vote| vote.voter_id }
              # Rails.logger   " => #{Time.now}       Splitting votes on timestamp_publication  :: END"

              # Rails.logger   " => #{Time.now}       Processing splitted votes  :: START"
              votes_published_news_list.keys.each do |published_news_event|
                votes_published_news_list[published_news_event].each_index do |index_vote|
                  vote = votes_published_news_list[published_news_event][index_vote]
                  ((index_vote + 1)..(votes_published_news_list[published_news_event].size - 1)).each do |index_covote|
                    covote = votes_published_news_list[published_news_event][index_covote]
                    if vote.rate >= 0 && covote.rate >= 0
                      local_voters_affinity[[vote.voter_id, covote.voter_id]][published_news_event]['+='] += 1
                    elsif vote.rate < 0 && covote.rate < 0
                      local_voters_affinity[[vote.voter_id, covote.voter_id]][published_news_event]['-='] += 1
                    else # vote['minor_rate'] >= 0 && covote['major_rate'] < 0 || vote['minor_rate'] < 0 && covote['major_rate'] >= 0
                      local_voters_affinity[[vote.voter_id, covote.voter_id]][published_news_event]['<>'] += 1
                    end
                  end
                end

              end
              # Rails.logger   " => #{Time.now}       Processing splitted votes  :: END"

              # Rails.logger   " => #{Time.now}     Processing affinities for published news :: END"
            end
          end

          mutex.synchronize do
            local_voters_affinity.each do |vote_pair, vote_pair_affinities|
              vote_pair_affinities.each do |status, affinities_list|
                voters_affinity[vote_pair][status]['+='] = voters_affinity[vote_pair][status]['+='] + affinities_list['+=']
                voters_affinity[vote_pair][status]['-='] = voters_affinity[vote_pair][status]['-='] + affinities_list['-=']
                voters_affinity[vote_pair][status]['<>'] = voters_affinity[vote_pair][status]['<>'] + affinities_list['<>']
              end
            end
          end

        end
      end
      threads.each { |thr| thr.join }

      ## Using threads (but not useful in MRI Ruby as it is pretty much single-threaded due to the GLI)
      # mutex = Mutex.new
      # threads = Array.new
      # votes_list_grouped = votes_list.group_by(&:votable_id)
      # votes_list_grouped.keys.each_slice(10).each do |votable_id_list_slice|
      #   threads << Thread.new(votable_id_list_slice) do |votable_id_list|
      #     local_voters_affinity = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = {'+=' => 0, '-=' => 0, '<>' => 0} } }
      #     votable_id_list.each do |votable_id|
      #       votes_news_set = votes_list_grouped[votable_id].to_set
      #       votes_list_grouped[votable_id].each do |vote|
      #         votes_news_set.delete(vote)
      #         votes_news_set.each do |covote|
      #           if vote.rate >= 0 && covote.rate >= 0
      #             local_voters_affinity[vote.voter_id][covote.voter_id]['+='] = local_voters_affinity[vote.voter_id][covote.voter_id]['+='] + 1
      #           elsif vote.rate < 0 && covote.rate < 0
      #             local_voters_affinity[vote.voter_id][covote.voter_id]['-='] = local_voters_affinity[vote.voter_id][covote.voter_id]['-='] + 1
      #           else # vote['minor_rate'] >= 0 && covote['major_rate'] < 0 || vote['minor_rate'] < 0 && covote['major_rate'] >= 0
      #             local_voters_affinity[vote.voter_id][covote.voter_id]['<>'] = local_voters_affinity[vote.voter_id][covote.voter_id]['<>'] + 1
      #           end
      #         end
      #       end
      #     end
      #
      #     mutex.synchronize do
      #       local_voters_affinity.each do |voter_id, covoters_list|
      #         covoters_list.each do |covoter_id, affinities_list|
      #           voters_affinity[voter_id][covoter_id]['+='] = voters_affinity[voter_id][covoter_id]['+='] + affinities_list['+=']
      #           voters_affinity[voter_id][covoter_id]['-='] = voters_affinity[voter_id][covoter_id]['-='] + affinities_list['-=']
      #           voters_affinity[voter_id][covoter_id]['<>'] = voters_affinity[voter_id][covoter_id]['<>'] + affinities_list['<>']
      #         end
      #       end
      #     end
      #   end
      # end
      # threads.each { |thr| thr.join }

      ## After retrieving the list of news within the given period, go thru each news' votes
      ## NOTE Very slow
      # news_list.each do |news|
      #   news_votes = news.votes.order(:voter_id)
      #   news_votes_set = news_votes.to_set
      #
      #   news_votes.each do |vote|
      #     #voters_affinity[vote.voter_id] = Hash.new({'=' => 0, '<>' => 0}) if voters_affinity[vote.voter_id].nil?
      #
      #     news_votes_set.delete(vote)
      #     news_votes_set.each do |vote_pair|
      #       if vote.rate >= 0 && vote_pair.rate >= 0
      #         voters_affinity[vote.voter_id][vote_pair.voter_id]['+='] = voters_affinity[vote.voter_id][vote_pair.voter_id]['+='] + 1
      #       elsif vote.rate < 0 && vote_pair.rate < 0
      #         voters_affinity[vote.voter_id][vote_pair.voter_id]['-='] = voters_affinity[vote.voter_id][vote_pair.voter_id]['-='] + 1
      #       else # vote.rate >= 0 && vote_pair.rate < 0 || vote.rate < 0 && vote_pair.rate >= 0
      #         voters_affinity[vote.voter_id][vote_pair.voter_id]['<>'] = voters_affinity[vote.voter_id][vote_pair.voter_id]['<>'] + 1
      #       end
      #     end
      #   end
      # end
      # Rails.logger   " => #{Time.now} Calculating affinities :: END"

      # Rails.logger   " => #{Time.now} Converting affinities to array :: START"
      # edges_list = Array.new
      # voters_affinity.each do |minor_voter, affinities|
      #   minor_node = Node.new(minor_voter)
      #   affinities.each do |major_voter, affinity_closeness|
      #     major_node = Node.new(major_voter)
      #     affinity_edge = Edge.new(minor_node, major_node, affinity_closeness)
      #     edges_list << affinity_edge
      #   end
      # end
      # edges_list.sort_by! { |i| (i.weight['+='] + i.weight['-='] + i.weight['<>']) }

      # TODO: This step can be skipped as the sort_by! method can do the sorting with the proper references
      # edges_list = Array.new
      # voters_affinity.each do |minor_voter, affinities|
      #   affinities.each do |major_voter, affinity_closeness|
      #     edges_list.push({'minor' => minor_voter, 'major' => major_voter, 'affinity' => affinity_closeness})
      #   end
      # end
      # Rails.logger  " => #{Time.now} Converting affnities to array :: END"

      # Rails.logger   " => #{Time.now} Sorting array of affinities :: START"
      #edges_list.sort_by! { |i| (i['affinity']['+='] + i['affinity']['-='] + i['affinity']['<>']) }
      edges_list = voters_affinity.sort_by do |k, v| #{ |k, v| v['+='] + v['-='] + v['<>']}
        v[:published_before]['+='] + v[:published_before]['-='] + v[:published_before]['<>'] +
        #  v[:published_after]['+='] + v[:published_after]['-='] + v[:published_after]['<>'] +
        #  v[:queued]['+='] + v[:queued]['-='] + v[:queued]['<>'] +
        #  v[:discarded]['+='] + v[:discarded]['-='] + v[:discarded]['<>'] +
        0
      end
      # Rails.logger   " => #{Time.now} Sorting array of affinities :: END"

      sorted_edges_list = edges_list.reverse

      affinities = []
      (0..[sorted_edges_list.size - 1, 10000 - 1].min).each do |i|
        voters_affinity[sorted_edges_list[i][0]].each do |status, status_affinities|
          affinity = Affinity.new(
            :minor_id => sorted_edges_list[i][0][0].to_i,
            :major_id => sorted_edges_list[i][0][1].to_i,
            :week     => week_range.begin.strftime('%W').to_i,
            :year     => week_range.begin.strftime('%Y').to_i,
            :status   => status.to_s,
            :closeness_pos => status_affinities['+='],
            :closeness_neg => status_affinities['-='],
            :closeness_dif => status_affinities['<>'],
          )
          affinities << affinity
        end
      end
      Affinity.import(affinities)

      # Rails.logger  "Week: #{news_list.first.timestamp_creation.strftime('%V').to_i} (#{news_list.size} news)"
      # (1..[sorted_edges_list.size, 15].min).each do |i|
      #   #Rails.logger  " - #{i} :: #{sorted_edges_list[i]}"
      #   Rails.logger  " - #{i} :: #{sorted_edges_list[i-1][0]} => #{sorted_edges_list[i-1][1]}"
      # end

      week_range = news_list.last.timestamp_creation.next_week.all_week
    end

  end

end
