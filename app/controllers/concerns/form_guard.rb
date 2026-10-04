# Cheap proof that a form was filled in by a person using a browser, with no
# third-party captcha. Scripted signups (about two thirds of new accounts in
# September 2026) fetch the form and post it straight back without running any
# JavaScript, so three checks cover them:
#   - a text field people never see must come back empty
#   - a field only the page's JavaScript fills in must come back filled
#   - the signed render time must be at least a couple of seconds old
# Render `shared/form_guard` inside the form, then call form_guard_failure in
# the action that receives it.
module FormGuard
  extend ActiveSupport::Concern

  HONEYPOT_FIELD = :subject_line
  MIN_AGE = 2.seconds
  # Public pages are cached for up to a day (stale-while-revalidate), and a
  # form can sit in an open tab; older than this is a replayed token.
  MAX_AGE = 2.days

  included do
    helper_method :form_guard_token
  end

  def form_guard_token
    Rails.application.message_verifier(:form_guard).generate(Time.current.to_i)
  end

  # nil when the submission looks human, otherwise the check it failed. Pass
  # min_age: 0 for a form that is a single button and can honestly be
  # submitted the moment it appears.
  def form_guard_failure(min_age: MIN_AGE)
    return 'honeypot' if params[HONEYPOT_FIELD].present?
    return 'no_js' unless params[:fg_js] == '1'

    rendered_at = Rails.application.message_verifier(:form_guard).verified(params[:fg_ts].to_s)
    return 'no_token' unless rendered_at.is_a?(Integer)

    age = Time.current.to_i - rendered_at
    return 'too_fast' if age < min_age
    return 'expired' if age > MAX_AGE

    nil
  end
end
