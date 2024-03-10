class StripeEventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    # Dynamically select the correct webhook secret for the environment
    stripe_webhook_secret = Rails.application.credentials.dig(:stripe, Rails.env.production? ? :live_webhook_secret : :test_webhook_secret)

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, stripe_webhook_secret
      )
    rescue JSON::ParserError => e
      render json: { error: 'Invalid payload' }, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      render json: { error: 'Invalid signature' }, status: 400
      return
    end

    # Process the Stripe event
    case event['type']
    when 'customer.subscription.created', 'invoice.payment_succeeded'
      handle_paid_user(event['data']['object'])
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event['data']['object'])
    else
      # Handle other event types
    end

    render json: { message: 'Success' }, status: 200
  end

  private

  def handle_paid_user(object)
    # Update user subscription status to active
  end

  def handle_subscription_deleted(object)
    # Update user subscription status to inactive
  end
end
