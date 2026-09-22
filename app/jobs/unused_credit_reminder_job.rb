# Enqueued once, 24h after signup. Sends only if the account is still idle:
# most new signups never spend their free credit, and this is the one nudge.
class UnusedCreditReminderJob < ApplicationJob
  queue_as :mailers

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil? || user.email == User::GUEST_EMAIL
    return if user.subscription_status == 'active' || user.credits.to_i < 1
    return if BuildingAnalysis.exists?(user_id: user.id) || ArchImageGen.exists?(user_id: user.id)

    UserMailer.unused_credit_reminder(user).deliver_now
    UserEvent.track(event_type: 'credit_reminder_sent', user: user)
  end
end
