module Targets
  class DetailsService
    include RoutesResolvable

    def initialize(target, founder)
      @target = target
      @founder = founder
    end

    def details
      {
        pending_founder_ids: pending_founder_ids,
        latest_event: latest_event_details,
        latest_event_attachments: latest_event_attachments,
        latest_feedback: latest_feedback_details,
        quiz_questions: quiz_questions,
        content_blocks: content_blocks
      }
    end

    private

    def pending_founder_ids
      @founder.startup.founders.where.not(id: @founder).reject do |founder|
        founder.exited? || founder.timeline_events.where(target: @target).passed.exists?
      end.map(&:id)
    end

    def latest_event_details
      return nil if latest_event.blank?

      latest_event.attributes.slice('id', 'title', 'description', 'created_at')
    end

    def latest_event
      @latest_event ||= @target.timeline_events.joins(:founders).where(founders: { id: @founder }).find_by(latest: true)
    end

    def latest_feedback_details
      return if latest_feedback.blank?

      latest_feedback.attributes.slice('faculty_id', 'feedback')
    end

    def latest_feedback
      @latest_feedback ||= latest_event&.startup_feedback&.order('created_at')&.last
    end

    def latest_event_attachments
      return nil if latest_event.blank?

      files = latest_event.timeline_event_files.map do |file|
        {
          type: "file",
          title: file.title,
          url: url_helpers.download_timeline_event_file_path(file)
        }
      end

      links = latest_event.links.map do |link|
        {
          type: "link",
          title: link[:title],
          url: link[:url]
        }
      end

      files + links
    end

    def linked_resources
      return if @target.resources.blank?

      @target.resources.with_attached_file.map do |resource|
        {
          id: resource.id,
          title: resource.title,
          slug: resource.slug,
          can_stream: resource.stream?,
          has_link: resource.link.present?,
          has_file: resource.file.attached?
        }
      end
    end

    def quiz_questions
      return [] if @target.quiz.blank?

      @target.quiz.quiz_questions.includes(:answer_options).each_with_index.map do |question, index|
        {
          index: index,
          question: question.question,
          description: question.description,
          correctAnswerId: question.correct_answer_id,
          answerOptions: answer_options(question).shuffle
        }
      end
    end

    def answer_options(question)
      question.answer_options.map do |answer|
        answer.attributes.slice('id', 'value', 'hint')
      end
    end

    def content_blocks
      @target.content_blocks.with_attached_file.map do |content_block|
        cb = content_block.attributes.slice('id', 'block_type', 'content', 'sort_index')
        cb['file_url'] = url_helpers.url_for(content_block.file) if content_block.file.attached?
        cb
      end
    end
  end
end
