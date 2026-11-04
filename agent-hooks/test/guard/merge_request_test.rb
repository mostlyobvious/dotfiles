require_relative "../support/guard_helpers"

module AgentHooks
  class MergeRequestPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::MergeRequest*"
    cover "AgentHooks::Guard::Policies.evaluate"

    def test_gitlab_merge_request_creation_runs_from_a_script
      assert_equal [2, MR_SCRIPT_MESSAGE],
                   call(
                     "glab mr create --squash-before-merge=false",
                     change_writing: true
                   )
    end

    def test_gitlab_merge_request_script_disables_squash
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create\n")

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call("./publish.sh", cwd: directory, change_writing: true)
      end
    end

    def test_gitlab_merge_request_script_with_squash_disabled_is_allowed
      Dir.mktmpdir do |directory|
        File.write(
          "#{directory}/publish.sh",
          "glab mr create --squash-before-merge=false\n"
        )

        assert_equal [0, ""],
                     call("./publish.sh", cwd: directory, change_writing: true)
      end
    end

    def test_gitlab_merge_request_script_after_another_command_is_guarded
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create\n")

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call(
                       "printf ready && ./publish.sh",
                       cwd: directory,
                       change_writing: true
                     )
      end
    end

    def test_missing_script_does_not_hide_a_later_merge_request_script
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish.sh", "glab mr create\n")

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call(
                       "./missing.sh && ./publish.sh",
                       cwd: directory,
                       change_writing: true
                     )
      end
    end

    def test_merge_request_creation_later_in_a_chain_runs_from_a_script
      assert_equal [2, MR_SCRIPT_MESSAGE],
                   call(
                     "printf ready && glab mr create --squash-before-merge=false",
                     change_writing: true
                   )
    end

    def test_script_without_sh_suffix_is_not_inspected
      Dir.mktmpdir do |directory|
        File.write("#{directory}/publish", "glab mr create\n")

        assert_equal [0, ""],
                     call("./publish", cwd: directory, change_writing: true)
      end
    end

    def test_assignment_only_command_is_not_a_script
      assert_equal [0, ""], call("FOO=bar", change_writing: true)
    end

    def test_only_create_commands_in_a_script_need_the_flag
      Dir.mktmpdir do |directory|
        File.write(
          "#{directory}/publish.sh",
          "printf ready\nglab mr create --squash-before-merge=false\n"
        )

        assert_equal [0, ""],
                     call("./publish.sh", cwd: directory, change_writing: true)
      end
    end

    def test_every_create_in_a_script_needs_the_flag
      Dir.mktmpdir do |directory|
        File.write(
          "#{directory}/publish.sh",
          "glab mr create --squash-before-merge=false\nglab mr create\n"
        )

        assert_equal [2, MR_SQUASH_MESSAGE],
                     call("./publish.sh", cwd: directory, change_writing: true)
      end
    end
  end
end
