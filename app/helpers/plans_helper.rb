module PlansHelper
  # Stripe Payment Link URL for a plan. For signed-in users, prefill their
  # email and pass their user id as client_reference_id so the webhook can
  # match the purchase to the account even if they pay with another email.
  def checkout_url(plan_key)
    plan = PLANS.fetch(plan_key)
    params = {}
    if user_signed_in?
      params[:prefilled_email] = current_user.email
      params[:client_reference_id] = current_user.id
    end
    url = plan[:link]
    url += "?#{params.to_query}" if params.any?
    url
  end

  # Where a plan CTA should point: checkout for signed-in users, sign-up
  # (returning to /pricing afterwards) for visitors.
  def plan_cta_path(plan_key)
    return checkout_url(plan_key) if user_signed_in?

    new_user_registration_path(return_to: 'pricing')
  end
end
