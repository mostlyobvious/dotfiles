require_relative "../support/guard_helpers"

module AgentHooks
  class ShellEditPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::ShellEdit*"
    cover "AgentHooks::Guard::Policies.evaluate"

    def test_sed_short_in_place_option_is_blocked
      assert_equal shell_edit_blocked("sed -i '' 's/old/new/' file"),
                   call("sed -i '' 's/old/new/' file")
    end

    def test_sed_long_in_place_option_is_blocked
      command = "sed --in-place=.bak 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_sed_long_in_place_flag_is_blocked
      command = "sed --in-place 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_sed_in_place_after_another_command_is_blocked
      command = "printf ready && sed -i.bak 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_perl_in_place_option_is_blocked
      command = "perl -pi -e 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_perl_bare_in_place_option_is_blocked
      command = "perl -i -e 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_perl_combined_in_place_option_is_blocked
      command = "perl -0777pi -e 's/old/new/' file"

      assert_equal shell_edit_blocked(command), call(command)
    end

    def test_sed_that_writes_to_stdout_is_allowed
      assert_equal [0, ""], call("sed 's/old/new/' file")
    end

    def test_similar_command_name_is_allowed
      assert_equal [0, ""], call("sediment -i file")
    end

    def test_perl_without_in_place_option_is_allowed
      assert_equal [0, ""], call("perl -pe 's/old/new/' file")
    end
  end
end
