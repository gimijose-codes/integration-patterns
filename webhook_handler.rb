# webhook_handler.rb
# Receives and validates incoming webhook events from external LMS systems
# Validates signature, ensures idempotency, and queues for async processing

require 'openssl'
require 'json'

class WebhookHandler
  WEBHOOK_SECRET = ENV['WEBHOOK_SECRET']

  # Entry point — call this when a webhook POST arrives
  def self.handle(request_body, signature_header)
    unless valid_signature?(request_body, signature_header)
      return { status: 401, message: 'Invalid signature' }
    end

    event = JSON.parse(request_body)
    event_id = event['id']

    # Idempotency check — if we've already processed this event, skip it
    # Webhooks from external systems can fire more than once
    if already_processed?(event_id)
      return { status: 200, message: 'Already processed' }
    end

    # Hand off to async queue — return 200 immediately
    # Never do heavy processing in the webhook receiver itself
    queue_for_processing(event)
    mark_as_processed(event_id)

    { status: 200, message: 'Received' }
  end

  private

  # Validates HMAC signature to confirm event is from trusted source
  def self.valid_signature?(body, signature)
    expected = OpenSSL::HMAC.hexdigest('SHA256', WEBHOOK_SECRET, body)
    Rack::Utils.secure_compare("sha256=#{expected}", signature)
  end

  # Placeholder — in production this checks a database or Redis cache
  def self.already_processed?(event_id)
    processed_event_ids.include?(event_id)
  end

  def self.mark_as_processed(event_id)
    processed_event_ids << event_id
  end

  def self.processed_event_ids
    @processed_event_ids ||= []
  end

  # Placeholder — in production this pushes to Sidekiq, SQS, or similar
  def self.queue_for_processing(event)
    puts "Queuing event #{event['id']} of type #{event['type']}"
  end
end
