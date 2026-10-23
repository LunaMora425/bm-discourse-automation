# frozen_string_literal: true

# name: bm-discourse-automation
# about: Extending the Discourse Automation plugin for BM's use case
# version: 0.0.1
# authors: LunaMora
# url: https://github.com/LunaMora425/bm-discourse-automation
# required_version: 2.7.0

enabled_site_setting :bm_discourse_automation_enabled

after_initialize do
  require_relative "lib/bm_title_pairing_matcher"

  on(:before_system_message_sent) do |message_type:, post_creator_args:, **|
    next unless SiteSetting.bm_discourse_automation_enabled
    next unless %w[welcome_user welcome_invite welcome_tl1_user].include?(message_type.to_s)

    post_creator_args.last[:target_group_names] = nil
  end

  NewPostManager.add_handler do |manager|
    next unless SiteSetting.bm_discourse_automation_enabled

    category_ids = SiteSetting.bm_ad_cooldown_categories_map
    next if category_ids.blank?

    user = manager.user
    next if user.staff? || !user.human?

    args = manager.args
    if args[:topic_id].present?
      topic = Topic.find_by(id: args[:topic_id])
      next unless topic
      next unless topic.user_id == user.id && category_ids.include?(topic.category_id)
    else
      next if args[:archetype] == Archetype.private_message
      next unless category_ids.include?(args[:category].to_i)
    end

    days = SiteSetting.bm_ad_cooldown_days
    last_posted_at =
      Post
        .with_deleted
        .joins("INNER JOIN topics ON topics.id = posts.topic_id")
        .where(user_id: user.id, post_type: Post.types[:regular])
        .where(topics: { user_id: user.id, category_id: category_ids })
        .where("posts.created_at > ?", days.days.ago)
        .maximum("posts.created_at")
    next unless last_posted_at

    next_post_at = (last_posted_at + days.days).in_time_zone(UserOption.user_tzinfo(user.id))

    result = NewPostResult.new(:bm_ad_cooldown, false)
    result.add_error(
      I18n.t(
        "bm_ad_cooldown.blocked",
        days: days,
        next_post_at: next_post_at.strftime("%A, %B %-d at %-l:%M %p %Z"),
      ),
    )
    result
  end

  add_model_callback(:topic, :validate) do
    next unless SiteSetting.bm_discourse_automation_enabled
    next unless new_record? || title_changed?
    next unless SiteSetting.bm_title_pairing_categories_map.include?(category_id)
    next if acting_user.nil? || acting_user.staff? || !acting_user.human?

    group_names = SiteSetting.bm_title_pairing_tag_groups.split("|")
    tag_names = Tag.joins(:tag_groups).where(tag_groups: { name: group_names }).pluck(:name)
    pairs = BmTitlePairingMatcher.pairs_from_tag_names(tag_names)
    slash_words = SiteSetting.bm_title_pairing_slash_words.split("|")

    old_keys =
      if new_record?
        []
      else
        BmTitlePairingMatcher.find(title_was, pairs, slash_words).map { |f| f[:key] }
      end
    added =
      BmTitlePairingMatcher.find(title, pairs, slash_words).reject { |f| old_keys.include?(f[:key]) }
    next if added.empty?

    errors.add(
      :base,
      I18n.t("bm_title_pairing.blocked", codes: added.map { |f| "\"#{f[:text]}\"" }.join(", ")),
    )
  end

  add_model_callback(:post_revision, :before_create) do
    next unless SiteSetting.bm_discourse_automation_enabled && SiteSetting.bm_quiet_staff_edits
    next if user.nil? || !user.staff? || post.nil? || user_id == post.user_id
    next if post.edit_reason.present?

    self.silent = true
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
