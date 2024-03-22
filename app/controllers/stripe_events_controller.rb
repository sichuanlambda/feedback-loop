class StripeEventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    stripe_webhook_secret = Rails.application.credentials.dig(:stripe, Rails.env.production? ? :live_webhook_secret : :test_webhook_secret)

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, stripe_webhook_secret)
    rescue JSON::ParserError => e
      render json: { error: 'Invalid payload' }, status: 400 and return
    rescue Stripe::SignatureVerificationError => e
      render json: { error: 'Invalid signature' }, status: 400 and return
    end

    case event['type']
    when 'customer.subscription.created', 'invoice.payment_succeeded'
      handle_paid_user(event['data']['object'])
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event['data']['object'])
    end

    render json: { message: 'Success' }, status: 200
  end

  private

  def handle_paid_user(object)
    update_subscription_status(object, 'active')
  end

  def handle_subscription_deleted(object)
    update_subscription_status(object, 'inactive')
  end

  def update_subscription_status(object, status)
    customer_id = object["customer"]
    begin
      customer = Stripe::Customer.retrieve(customer_id)
      user_email = customer.email
      user = User.find_by(email: user_email)
      if user
        user.update!(subscription_status: status)
        Rails.logger.info "Updated user #{user.email} to #{status} subscription"
      else
        Rails.logger.error "User not found with email: #{user_email}"
      end
    rescue => e
      Rails.logger.error "Failed to update subscription status for customer #{customer_id}: #{e.message}"
    end
  end
end
