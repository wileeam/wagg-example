namespace :graph do

  namespace :affinity do

    desc "Calculates affinities between users on a weekly basis and votes before publication or till end of news' lifetime in queue"
    task :calculate  => :environment do

      if Affinity.maximum(:timestamp_end).nil?
        week = News.complete.votes_complete.minimum(:timestamp_creation).all_week
      else
        if Affinity.maximum(:timestamp_end).to_i < 30.days.ago.prev_week.end_of_week.to_i
          if Affinity.maximum(:timestamp_end).to_i == Affinity.maximum(:timestamp_end).all_week.end.to_i
            week = Affinity.maximum(:timestamp_end).next_week.all_week
          else
            week = Affinity.maximum(:timestamp_end).all_week
          end
        else
          week = 30.days.ago.prev_week.all_week
        end
      end

      while week.end.to_i < 30.days.ago.prev_week.end_of_week.to_i

        day_range = week.begin.all_day
        while day_range.end.to_i <= week.end.to_i
          #calculate affinities for the given range
          unsorted_affinities = AffinityCalculator.by_date_range(day_range)

          #retrieve affinities from database
          stored_affinities = Affinity.where('timestamp_begin >= ?', week.begin).where('timestamp_end <= ?', day_range.end)

          #merge stored_affinities into affinities
          stored_affinities.each do |affinity|
            if unsorted_affinities.has_key?([affinity.minor_id, affinity.major_id])
              unsorted_affinities[[affinity.minor_id, affinity.major_id]][affinity.status.to_sym][:closeness_pos] += affinity.closeness_pos
              unsorted_affinities[[affinity.minor_id, affinity.major_id]][affinity.status.to_sym][:closeness_neg] += affinity.closeness_neg
              unsorted_affinities[[affinity.minor_id, affinity.major_id]][affinity.status.to_sym][:closeness_dif] += affinity.closeness_dif
            else
              unsorted_affinities[[affinity.minor_id, affinity.major_id]][affinity.status.to_sym][:closeness_pos] = affinity.closeness_pos
              unsorted_affinities[[affinity.minor_id, affinity.major_id]][affinity.status.to_sym][:closeness_neg] = affinity.closeness_neg
              unsorted_affinities[[affinity.minor_id, affinity.major_id]][affinity.status.to_sym][:closeness_dif] = affinity.closeness_dif
            end
          end

          #sort affinities with AffinityCalculator.sort method (and criteria)
          sorted_affinities = AffinityCalculator.sort(unsorted_affinities)
          #reverse the sorting
          sorted_affinities.reverse!

          #delete all stored_affinities in interval: week.begin - day_range.end
          stored_affinities.delete_all

          #import first 10000 affinities of affinities with new interval: week.begin - day_range.end
          unless sorted_affinities.empty?
            affinities = Array.new

            (0..[9999, sorted_affinities.size - 1].min).each do |i|
              [:published_before, :published_after, :queued, :discarded].each do |status|
                affinities << Affinity.new(
                    :minor_id => sorted_affinities[i][0][0].to_i,
                    :major_id => sorted_affinities[i][0][1].to_i,
                    :timestamp_begin => week.begin,
                    :timestamp_end => day_range.end,
                    :status => status.to_s,
                    :closeness_pos => sorted_affinities[i][1][status][:closeness_pos].to_i,
                    :closeness_neg => sorted_affinities[i][1][status][:closeness_neg].to_i,
                    :closeness_dif => sorted_affinities[i][1][status][:closeness_dif].to_i
                )
              end
            end

            Affinity.import(affinities)
          end

          #loop to the next day
          day_range = (day_range.begin + 1.day).all_day
        end

        #loop to the next week
        week = week.begin.next_week.all_week
      end

    end

  end

end
