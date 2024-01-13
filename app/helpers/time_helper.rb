module TimeHelper
  def precise_time_ago_in_words(from_time)
    to_time = Time.current
    distance_in_hours = ((to_time - from_time) / 1.hour).round
    distance_in_days = ((to_time - from_time) / 1.day).round

    if distance_in_hours < 24
      "#{distance_in_hours} hour".pluralize(distance_in_hours)
    else
      "#{distance_in_days} day".pluralize(distance_in_days)
    end
  end
end
