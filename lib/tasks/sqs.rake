# frozen_string_literal: true

namespace :sqs do
  task subscribe: :environment do
    queue_name = "Message.fifo"

    sqs = Aws::SQS::Client.new(
      region: "ap-southeast-2",
      credentials: Aws::Credentials.new(
        ENV["AWS_ACCESS_KEY"],
        ENV["AWS_SECRET_ACCESS_KEY"]
      )
    )

    queue_url = sqs.get_queue_url(queue_name: queue_name).queue_url

    loop do
      receive_message_result = sqs.receive_message({
        queue_url: queue_url,
        message_attribute_names: ["All"],
        max_number_of_messages: 5,
        wait_time_seconds: 20
      })

      timestamp = Time.new
      

      # receive_message_result.messages.each do |message|
      #   puts "#{timestamp.strftime("%Y-%m-%d %H:%M:%S")}: #{message.body}"

      #   destination = Destination.find(4)
      #   pipeline = Pipeline.find(79)
      #   job = PipelineJob.create(
      #     pipeline:, 
      #     key: SecureRandom.hex, 
      #     destination:, 
      #     harvest_definitions_to_run: pipeline.harvest_definitions.map(&:id) 
      #   )

      #   PipelineWorker.perform_async(job.id)

      #   sqs.delete_message({
      #     queue_url: queue_url,
      #     receipt_handle: message.receipt_handle
      #   })
      # end
    end
  end
end


