namespace :analytics do
  desc "Print 7-day event analytics summary"
  task summary: :environment do
    puts "=== Analytics Summary (Last 7 Days) ==="
    puts

    events = UserEvent.where(created_at: 7.days.ago..)
    puts "Total events: #{events.count}"
    puts "Unique sessions: #{events.distinct.count(:session_id)}"
    puts "Unique users: #{events.where.not(user_id: nil).distinct.count(:user_id)}"
    puts

    puts "Events by type:"
    events.group(:event_type).order("count_all DESC").count.each do |type, count|
      puts "  #{type}: #{count}"
    end
    puts

    puts "Events per day:"
    events.group("DATE(created_at)").order("DATE(created_at)").count.each do |date, count|
      puts "  #{date}: #{count}"
    end
  end
end
