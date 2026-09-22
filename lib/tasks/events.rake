namespace :events do
  desc "Flag historical crawler rows in user_events (bot = true). Safe to re-run; batches of 50k."
  task backfill_bot: :environment do
    scope = UserEvent.where(bot: false).where.not(user_agent: [nil, ''])
    scope = if UserEvent.connection.adapter_name.match?(/postg/i)
              scope.where('user_agent ~* ?', BotDetector::SQL_PATTERN)
            else
              scope.where(BotDetector::LIKE_TERMS.map { 'user_agent LIKE ?' }.join(' OR '), *BotDetector::LIKE_TERMS.map { |t| "%#{t}%" })
            end

    total = 0
    scope.in_batches(of: 50_000) do |batch|
      n = batch.update_all(bot: true)
      total += n
      puts "flagged #{n} (#{total} so far)"
    end
    puts "Done: #{total} rows flagged as bots; #{UserEvent.where(bot: true).count} total bot rows, #{UserEvent.where(bot: false).count} human rows."
  end
end
