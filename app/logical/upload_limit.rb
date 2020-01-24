class UploadLimit
  extend Memoist

  INITIAL_POINTS = 1000
  MAXIMUM_POINTS = 10000

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def limited?
    used_upload_slots >= upload_slots
  end

  def used_upload_slots
    pending = user.posts.pending
    early_deleted = user.posts.deleted.where("created_at >= ?", 3.days.ago)

    pending.or(early_deleted).count
  end

  def upload_slots
    upload_level + 5
  end

  def upload_level
    UploadLimit.points_to_level(user.upload_points)
  end

  def approvals_on_current_level
    (user.upload_points - UploadLimit.level_to_points(upload_level)) / 10
  end

  def approvals_for_next_level
    UploadLimit.points_for_next_level(upload_level) / 10
  end

  def update_limit!(post)
    user.with_lock do
      user.upload_points += UploadLimit.upload_value(user.upload_points, post.is_deleted)
      user.save!
    end
  end

  def recalculate_limit!
    user.with_lock do
      user.update!(upload_points: UploadLimit.points_for_user(user))
    end
  end

  def self.points_for_user(user)
    points = INITIAL_POINTS

    uploads = user.posts.where(is_pending: false).order(id: :asc).pluck(:is_deleted)
    uploads.each do |is_deleted|
      points += upload_value(points, is_deleted)
      points = points.clamp(0, MAXIMUM_POINTS)

      #warn "slots: %2d, points: %3d, value: %2d" % [UploadLimit.points_to_level(points) + 5, points, UploadLimit.upload_value(level, is_deleted)]
    end

    points
  end

  def self.upload_value(current_points, is_deleted)
    if is_deleted
      level = points_to_level(current_points)
      -1 * (points_for_next_level(level) / 3.0).round.to_i
    else
      10
    end
  end

  def self.points_for_next_level(level)
    100 + 20 * [level - 10, 0].max
  end

  def self.points_to_level(points)
    level = 0

    loop do
      points -= points_for_next_level(level)
      break if points < 0
      level += 1
    end

    level
  end

  def self.level_to_points(level)
    (1..level).map do |n|
      points_for_next_level(n - 1)
    end.sum
  end

  memoize :used_upload_slots
end
