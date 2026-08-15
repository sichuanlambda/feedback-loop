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
    when 'checkout.session.completed'
      handle_checkout_completed(event['data']['object'])
    when 'customer.subscription.created', 'invoice.payment_succeeded'
      handle_paid_user(event['data']['object'])
    when 'customer.subscription.updated'
      handle_subscription_updated(event['data']['object'])
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event['data']['object'])
    when 'invoice.payment_failed'
      Rails.logger.warn "Stripe payment failed for customer #{event['data']['object']['customer']}"
    end

    render json: { message: 'Success' }, status: 200
  end

  private

  def handle_paid_user(object)
    update_subscription_status(object, 'active')
  end

  # Payment Links fire this with client_reference_id (the app user id, when we
  # passed one) — the most reliable link between a purchase and an account,
  # even when the buyer used a different email at checkout.
  def handle_checkout_completed(object)
    user = User.find_by(id: object['client_reference_id']) if object['client_reference_id'].present?
    if user
      user.update_columns(subscription_status: 'active', stripe_customer_id: object['customer'])
      Rails.logger.info "Checkout completed: user #{user.email} active (stripe: #{object['customer']})"
    else
      # Fall back to customer-id/email matching
      update_subscription_status(object, 'active')
    end
  end

  # Keep local status in sync with Stripe's lifecycle. past_due keeps access
  # while Stripe retries the card; canceled/unpaid cuts it off.
  def handle_subscription_updated(object)
    case object['status']
    when 'active', 'trialing', 'past_due'
      update_subscription_status(object, 'active')
    when 'canceled', 'unpaid', 'incomplete_expired'
      update_subscription_status(object, 'inactive')
    end
  end

  def handle_subscription_deleted(object)
    update_subscription_status(object, 'inactive')
  end

  def update_subscription_status(object, status)
    customer_id = object["customer"]
    begin
      # First try matching by stripe_customer_id (most reliable)
      user = User.find_by(stripe_customer_id: customer_id)

      # Fall back to email matching (case-insensitive)
      unless user
        customer = Stripe::Customer.retrieve(customer_id)
        user_email = customer.email
        user = User.where('LOWER(email) = ?', user_email.to_s.downcase).first if user_email.present?
      end

      if user
        user.update_columns(subscription_status: status, stripe_customer_id: customer_id)
        Rails.logger.info "Updated user #{user.email} to #{status} subscription (stripe: #{customer_id})"
      else
        Rails.logger.error "User not found for Stripe customer #{customer_id} (email: #{user_email})"
      end
    rescue => e
      Rails.logger.error "Failed to update subscription status for customer #{customer_id}: #{e.message}"
    end
  end
end
