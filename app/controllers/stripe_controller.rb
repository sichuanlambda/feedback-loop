class StripeController < ApplicationController
  def checkout
    session = Stripe::Checkout::Session.create(
      payment_method_types: ['card'],
      line_items: [{
        name: "Subscription",
        amount: 500, # Set your amount
        currency: 'usd',
        quantity: 1
      }],
      success_url: 'http://localhost:3000/users/sign_up?success=true',
      cancel_url: 'http://localhost:3000/users/sign_up?cancelled=true',
    )

    render json: { id: session.id }
  end
end
