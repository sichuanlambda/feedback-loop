class StripeEventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    stripe_webhook_secret = if Rails.env.production?
      Rails.application.credentials.stripe[:live_webhook_secret]
    else
      Rails.application.credentials.stripe[:test_webhook_secret]
    end

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, stripe_webhook_secret
      )
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      render json: { message: e.message }, status: 400
      return
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
    update_user_subscription_status(object['customer'], true)
  end

  def handle_subscription_deleted(object)
    update_user_subscription_status(object['customer'], false)
  end

  def update_user_subscription_status(customer_id, is_paid)
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update(
        paid: is_paid,
        # Update additional fields as needed, e.g., subscription_status
        subscription_status: is_paid ? 'active' : 'canceled'
      )
      Rails.logger.info "User #{user.id} subscription status updated to #{is_paid ? 'paid' : 'not paid'}."
    else
      Rails.logger.error "User with Stripe customer ID #{customer_id} not found."
    end
  end
end
