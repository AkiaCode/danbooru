require 'test_helper'

class UploadLimitTest < ActiveSupport::TestCase
  context "Upload limits:" do
    setup do
      @user = create(:user, upload_points: 1000)
      @approver = create(:moderator_user)
    end

    context "a pending post that is deleted" do
      should "decrease the uploader's upload points" do
        @post = create(:post, uploader: @user, is_pending: true, created_at: 7.days.ago)
        assert_equal(1000, @user.reload.upload_points)

        PostPruner.new.prune!
        assert_equal(967, @user.reload.upload_points)
      end
    end

    context "a pending post that is approved" do
      should "increase the uploader's upload points" do
        @post = create(:post, uploader: @user, is_pending: true, created_at: 7.days.ago)
        assert_equal(1000, @user.reload.upload_points)

        @post.approve!(@approver)
        assert_equal(1010, @user.reload.upload_points)
      end
    end

    context "an approved post that is deleted" do
      should "decrease the uploader's upload points" do
        @post = create(:post, uploader: @user, is_pending: true)
        assert_equal(1000, @user.reload.upload_points)

        @post.approve!(@approver)
        assert_equal(1010, @user.reload.upload_points)

        as(@approver) { @post.delete!("bad") }
        assert_equal(967, @user.reload.upload_points)
      end
    end

    context "a deleted post that is undeleted" do
      should "increase the uploader's upload points" do
        @post = create(:post, uploader: @user)
        as(@approver) { @post.delete!("bad") }
        assert_equal(967, @user.reload.upload_points)

        @post.approve!(@approver)
        assert_equal(1010, @user.reload.upload_points)
      end
    end
  end
end
