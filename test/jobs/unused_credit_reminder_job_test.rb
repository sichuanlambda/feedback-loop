require "test_helper"

class UnusedCreditReminderJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  def idle_user
    User.create!(email: "idle@example.com", password: "password123", terms_of_service: "1")
  end

  test "signing up schedules one reminder a day out" do
    assert_enqueued_with(job: UnusedCreditReminderJob) { idle_user }
  end

  test "emails an account that never used its credit" do
    user = idle_user
    assert_emails(1) { UnusedCreditReminderJob.perform_now(user.id) }
    mail = ActionMailer::Base.deliveries.last
    assert_equal ["idle@example.com"], mail.to
    assert_includes mail.text_part.decoded, "src=credit_reminder_email"
    assert_includes mail.html_part.decoded, "src=credit_reminder_email"
  end

  test "stays quiet once the user has analyzed a building" do
    user = idle_user
    BuildingAnalysis.create!(user: user, html_content: "<p>done</p>")
    assert_no_emails { UnusedCreditReminderJob.perform_now(user.id) }
  end

  test "stays quiet for subscribers, spent credits, and deleted users" do
    subscriber = idle_user
    subscriber.update_columns(subscription_status: "active")
    assert_no_emails { UnusedCreditReminderJob.perform_now(subscriber.id) }

    subscriber.update_columns(subscription_status: nil, credits: 0)
    assert_no_emails { UnusedCreditReminderJob.perform_now(subscriber.id) }

    assert_no_emails { UnusedCreditReminderJob.perform_now(-1) }
  end
end
