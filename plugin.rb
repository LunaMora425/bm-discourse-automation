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
  # ============================================================

  on(:topic_status_updated) do |topic, status, enabled|
    next unless status == "archived" && enabled

    source_category = topic.category
    next unless source_category

    mappings = SiteSetting.bm_archive_category_map
    next if mappings.blank?

    match =
      mappings.find do |m|
        source_ids = Array(m["source_category"]).map(&:to_i)
        source_ids.include?(source_category.id)
      end
    next unless match

    archive_id = Array(m["archive_category"]).first.to_i
    archive_category = Category.find_by(id: archive_id)
    next unless archive_category
    next if topic.category_id == archive_category.id

    topic.change_category_to_id(archive_category.id)
    topic.save!
  end
end
