namespace :subscriptions do
  desc "Compare users marked 'active' with Stripe. Dry run by default; APPLY=1 deactivates the ones Stripe says are not paying. SKIP=a@x.com,b@y.com leaves those accounts alone (comps, etc.)."
  task reconcile: :environment do
    apply = ENV['APPLY'] == '1'
    skip_emails = ENV['SKIP'].to_s.split(',').map(&:strip).reject(&:blank?)
    paying_statuses = %w[active trialing past_due]
    stale = []

    User.where(subscription_status: 'active').find_each do |user|
      customer_ids = [user.stripe_customer_id.presence].compact
      customer_ids = Stripe::Customer.list(email: user.email, limit: 5).data.map(&:id) if customer_ids.empty?

      subscriptions = customer_ids.flat_map { |cid| Stripe::Subscription.list(customer: cid, status: 'all', limit: 10).data }
      paying = subscriptions.select { |s| paying_statuses.include?(s.status) }

      if paying.any?
        puts "OK      #{user.email} — #{paying.map(&:status).join(', ')}"
      elsif user.admin?
        puts "SKIP    #{user.email} — admin account, no Stripe subscription"
      elsif skip_emails.include?(user.email)
        puts "SKIP    #{user.email} — excluded via SKIP"
      elsif user.subscription_expires_at&.future?
        # An annual plan that was canceled (or never set to renew) is still paid
        # for until it expires; expire_lapsed_subscription cuts it off on time.
        puts "PAID    #{user.email} — no live Stripe subscription, but paid through #{user.subscription_expires_at.to_date}"
      else
        reason = customer_ids.empty? ? 'no Stripe customer' : "Stripe says: #{subscriptions.map(&:status).uniq.join(', ').presence || 'no subscriptions'}"
        puts "STALE   #{user.email} — #{reason}"
        stale << user
      end
    end

    puts "\n#{stale.size} stale 'active' account(s)."
    if stale.empty?
      # nothing to do
    elsif apply
      stale.each { |u| u.update_columns(subscription_status: 'inactive', subscription_expires_at: nil) }
      puts "Marked #{stale.size} account(s) inactive."
    else
      puts "Dry run — nothing changed. Re-run with APPLY=1 to mark them inactive."
    end
  end
end
