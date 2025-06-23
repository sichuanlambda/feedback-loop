namespace :users do
  desc "List all users with their creation dates"
  task list: :environment do
    include ActionView::Helpers::DateHelper
    
    puts "=" * 80
    puts "ALL USERS AND CREATION DATES"
    puts "=" * 80
    
    users = User.order(:created_at)
    
    if users.empty?
      puts "No users found in the database."
    else
      puts sprintf("%-5s %-30s %-25s %-20s", "ID", "EMAIL", "NAME", "CREATED")
      puts "-" * 80
      
      users.each do |user|
        created_date = user.created_at.strftime("%Y-%m-%d %H:%M:%S")
        name = user.public_name.present? ? user.public_name : "N/A"
        admin_status = user.admin? ? " (ADMIN)" : ""
        
        puts sprintf("%-5s %-30s %-25s %-20s", 
          user.id, 
          user.email, 
          name + admin_status, 
          created_date
        )
      end
      
      puts "-" * 80
      puts "Total users: #{users.count}"
      puts "Admin users: #{users.where(admin: true).count}"
      puts "Regular users: #{users.where(admin: false).count}"
      
      # Show recent activity
      puts "\n" + "=" * 80
      puts "RECENT USER ACTIVITY (Last 7 days)"
      puts "=" * 80
      
      recent_users = users.where("created_at >= ?", 7.days.ago)
      if recent_users.any?
        recent_users.each do |user|
          puts "#{user.email} - #{time_ago_in_words(user.created_at)} ago"
        end
      else
        puts "No new users in the last 7 days."
      end
    end
    
    puts "\n" + "=" * 80
  end
end 