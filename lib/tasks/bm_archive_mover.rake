# frozen_string_literal: true

desc "Retroactively move auto-closed topics to their archive category based on bm_archive_category_map"
task "bm:move_closed_to_archive" => :environment do
  raw = SiteSetting.bm_archive_category_map
  mappings =
    if raw.is_a?(String)
      begin
        JSON.parse(raw)
      rescue StandardError
        []
      end
    else
      Array(raw)
    end

  eligible = mappings.select { |m| m["move_closed_to_archive"] }

  if eligible.blank?
    puts "No mappings have 'move_closed_to_archive' enabled. Nothing to do."
    next
  end

  total_moved = 0

  eligible.each do |mapping|
    source_ids = Array(mapping["source_category"]).map(&:to_i)
    archive_id = Array(mapping["archive_category"]).first.to_i
    archive_category = Category.find_by(id: archive_id)

    unless archive_category
      puts "WARNING: Archive category ID #{archive_id} not found, skipping mapping."
      next
    end

    topics =
      Topic
        .where(category_id: source_ids)
        .where(closed: true)
        .where(closed_by_id: Discourse::SYSTEM_USER_ID)

    puts "Found #{topics.count} topic(s) in source category IDs #{source_ids.inspect} → archive '#{archive_category.name}'"

    topics.each do |topic|
      begin
        topic.change_category_to_id(archive_category.id)
        topic.save!
        puts "  Moved: \"#{topic.title}\" (ID #{topic.id})"
        total_moved += 1
      rescue => e
        puts "  ERROR moving topic ID #{topic.id}: #{e.message}"
      end
    end
  end

  puts "\nDone. #{total_moved} topic(s) moved."
end
