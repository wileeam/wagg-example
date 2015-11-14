module Queriable
  extend ActiveSupport::Concern

  included do

  end
=begin
  included do
    has_many :taggings, as: :taggable
    has_many :tags, through: :taggings

    class_attribute :tag_limit
  end

  def tags_string
    tags.map(&:name).join(', ')
  end

  def tags_string=(tag_string)
    tag_names = tag_string.to_s.split(', ')

    tag_names.each do |tag_name|
      tags.build(name: tag_name)
    end
  end
=end

  # methods defined here are going to extend the class, not the instance of it
  module ClassMethods
=begin
    def tag_limit(value)
      self.tag_limit_value = value
    end
=end

    ["url", "id"].each do |action|
      define_method("complete_comment_by_#{action}") do |*args|
        comment = nil
        case action
          when 'url'
            comment = nil
          when 'id'
            comment = Wagg.crawl_comment(args[0], args[1])
          else
            #TODO: Implement undefined MethodError handling
        end

        comment
      end
    end


    def complete_comments

    end

    # Completes the information about votes of comments
    def complete_comment_votes(comment_id)
      comment = Comment.find_by(:id => comment_id)

      if comment.vote_count.nil? && coment.votes.nil?
        comment_object = Wagg::Crawler.comment
      else
        # Throw error or mark the comment's votes as non-recoverable?
      end

    end

  end

end