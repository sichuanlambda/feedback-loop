namespace :achievements do
  desc "Retroactively award all achievements users have earned but never received"
  task backfill: :environment do
    puts "Loading achievement config..."
    config = YAML.load_file(Rails.root.join('config', 'gamification', 'achievements.yml'))
    achievements = config['achievements']
    
    users = User.where.not(email: 'atlas@architecturehelper.com').includes(:user_level, :user_style_collections, :user_achievements, :building_analyses)
    total_awarded = 0
    
    puts "Checking #{users.count} users against #{achievements.count} achievements..."
    
    users.find_each do |user|
      newly_earned = AchievementCheckingService.check_achievements(user)
      if newly_earned.any?
        names = newly_earned.map { |a| JSON.parse(a.metadata)['name'] rescue a.achievement_key }
        puts "  #{user.public_name || user.handle || user.email}: +#{newly_earned.count} (#{names.join(', ')})"
        total_awarded += newly_earned.count
        
        # Update user_level achievements_earned count
        if user.user_level
          user.user_level.update(achievements_earned: user.user_achievements.count)
        end
      end
    end
    
    puts "\nDone! Awarded #{total_awarded} achievements across #{users.count} users."
  end
end
