# frozen_string_literal: true

# name: bm-discourse-automation
# about: Extending the Discourse Automation plugin for BM's use case
# version: 0.0.1
# authors: LunaMora
# url: https://github.com/LunaMora425/bm-discourse-automation
# required_version: 2.7.0

enabled_site_setting :bm_discourse_automation_enabled

after_initialize do

  # ============================================================
  # AUTOMATION 1: Archive Mover
  # Moves topics to a paired archive category when archived.
  # Config: JSON map of { "source-slug" => "archive-slug" }
  # ============================================================

  on(:topic_status_updated) do |topic, status, enabled|
    next unless status == "archived" && enabled

    source_category = topic.category
    next unless source_category

    raw_map = SiteSetting.bm_archive_category_map
    archive_map = JSON.parse(raw_map) rescue {}

    archive_slug = archive_map[source_category.slug]
    next unless archive_slug

    archive_category = Category.find_by(slug: archive_slug)
    next unless archive_category
    next if topic.category_id == archive_category.id

    topic.change_category_to_id(archive_category.id)
    topic.save!
  end

end