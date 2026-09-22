class UserMailer < ApplicationMailer
  # One-time nudge for new accounts that never spent their free credit
  def unused_credit_reminder(user)
    @user = user
    @analyze_url = architecture_explorer_new_url(src: 'credit_reminder_email')
    @restyle_url = restyle_url(src: 'credit_reminder_email')
    mail(to: user.email, subject: 'Your free building analysis is still waiting')
  end
end
