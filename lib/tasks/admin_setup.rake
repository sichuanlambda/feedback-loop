namespace :admin do
  desc "Make a user an admin by email"
  task :make_admin, [:email] => :environment do |task, args|
    email = args[:email]
    
    if email.blank?
      puts "Usage: rails admin:make_admin[user@example.com]"
      exit 1
    end
    
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User with email '#{email}' not found."
      exit 1
    end
    
    user.update!(admin: true)
    puts "Successfully made #{user.email} an admin!"
  end

  desc "List all admin users"
  task list_admins: :environment do
    admins = User.where(admin: true)
    
    if admins.empty?
      puts "No admin users found."
    else
      puts "Admin users:"
      admins.each do |admin|
        puts "  - #{admin.email} (#{admin.public_name})"
      end
    end
  end

  desc "Remove admin status from a user by email"
  task :remove_admin, [:email] => :environment do |task, args|
    email = args[:email]
    
    if email.blank?
      puts "Usage: rails admin:remove_admin[user@example.com]"
      exit 1
    end
    
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User with email '#{email}' not found."
      exit 1
    end
    
    user.update!(admin: false)
    puts "Successfully removed admin status from #{user.email}!"
  end
end 