# frozen_string_literal: true

# name: bm-discourse-automation
# about: Extending the Discourse Automation plugin for BM's use case
# version: 0.0.1
# authors: LunaMora
# url: https://github.com/LunaMora425/bm-discourse-automation
# required_version: 2.7.0

enabled_site_setting :bm_discourse_automation_enabled

after_initialize do
  on(:before_system_message_sent) do |message_type:, post_creator_args:, **|
    next unless SiteSetting.bm_discourse_automation_enabled
    next unless %w[welcome_user welcome_invite welcome_tl1_user].include?(message_type.to_s)

    post_creator_args.last[:target_group_names] = nil
  end

  on(:topic_status_updated) do |topic, status, enabled|
    next unless status == "archived" && enabled

    source_category = topic.category
    next unless source_category

    raw = SiteSetting.bm_archive_category_map
    mappings =
      (
        if raw.is_a?(String)
          (
            begin
              JSON.parse(raw)
            rescue StandardError
              []
            end
          )
        else
          Array(raw)
        end
      )
    next if mappings.blank?

    match =
      mappings.find do |m|
        source_ids = Array(m["source_category"]).map(&:to_i)
        source_ids.include?(source_category.id)
      end
    next unless match

    archive_id = Array(match["archive_category"]).first.to_i
    archive_category = Category.find_by(id: archive_id)
    next unless archive_category
    next if topic.category_id == archive_category.id

    topic.change_category_to_id(archive_category.id)
    topic.save!
  end

  on(:topic_status_updated) do |topic, status, enabled|
    next unless status == "autoclosed" && enabled

    source_category = topic.category
    next unless source_category

    raw = SiteSetting.bm_archive_category_map
    mappings =
      (
        if raw.is_a?(String)
          (
            begin
              JSON.parse(raw)
            rescue StandardError
              []
            end
          )
        else
          Array(raw)
        end
      )
    next if mappings.blank?

    match =
      mappings.find do |m|
        next unless m["move_closed_to_archive"]
        source_ids = Array(m["source_category"]).map(&:to_i)
        source_ids.include?(source_category.id)
      end
    next unless match

    archive_id = Array(match["archive_category"]).first.to_i
    archive_category = Category.find_by(id: archive_id)
    next unless archive_category
    next if topic.category_id == archive_category.id

    topic.change_category_to_id(archive_category.id)
    topic.save!
  end
end
