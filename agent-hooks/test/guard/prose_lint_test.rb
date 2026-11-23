require_relative "../support/guard_helpers"

module AgentHooks
  class ProseLintPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::ProseLint*"

    MESSAGE = "Document hook policy\n\nExplain why.\n"

    def test_commit_message_with_an_alert_is_blocked
      with_linter(reporting: { "draft.md" => [alert(3, "Drop it.")] }) do
        with_commit_message(MESSAGE) do |path|
          assert_equal [2, <<~TEXT],
                         BLOCKED: the change-writing linter rejects this prose:
                         - message:3 Drop it.
                         Revise it, then retry.
                       TEXT
                       call("git commit -F #{path}", change_writing: true)
        end
      end
    end

    def test_every_alert_is_listed
      alerts = [alert(1, "First."), alert(4, "Second.")]
      with_linter(reporting: { "draft.md" => alerts }) do
        with_commit_message(MESSAGE) do |path|
          assert_equal [2, <<~TEXT],
                         BLOCKED: the change-writing linter rejects this prose:
                         - message:1 First.
                         - message:4 Second.
                         Revise it, then retry.
                       TEXT
                       call("git commit -F #{path}", change_writing: true)
        end
      end
    end

    def test_clean_prose_is_allowed
      with_linter(reporting: {}) do
        with_commit_message(MESSAGE) do |path|
          assert_equal [0, ""],
                       call("git commit -F #{path}", change_writing: true)
        end
      end
    end

    def test_commit_message_reaches_the_linter_as_a_draft
      with_linter(reporting: {}) do |record|
        with_commit_message(MESSAGE) do |path|
          call("git commit -F #{path}", change_writing: true)

          assert_equal "arguments:\n#{MESSAGE}", File.read(record)
        end
      end
    end

    def test_description_reaches_the_linter_by_its_path
      with_linter(reporting: {}) do |record|
        Dir.mktmpdir do |directory|
          description = "#{directory}/mr-description.md"
          File.write(description, "The problem we're solving is that.\n")
          call("mr-describe 42 #{description}", change_writing: true)

          assert_equal "arguments:#{description}\n", File.read(record)
        end
      end
    end

    def test_linter_failure_blocks
      with_linter(failing_with: "vale: unknown style") do
        with_commit_message(MESSAGE) do |path|
          assert_equal [2, <<~TEXT],
                         BLOCKED: the change-writing linter rejects this prose:
                         - message: the linter failed: vale: unknown style
                         Revise it, then retry.
                       TEXT
                       call("git commit -F #{path}", change_writing: true)
        end
      end
    end

    def test_missing_linter_allows_the_commit
      with_commit_message(MESSAGE) do |path|
        assert_equal [0, ""],
                     call("git commit -F #{path}", change_writing: true)
      end
    end

    private

    def alert(line, message)
      { "Line" => line, "Message" => message }
    end

    def with_linter(reporting: nil, failing_with: nil)
      Dir.mktmpdir do |bin|
        record = "#{bin}/record"
        output =
          if failing_with
            "echo '#{failing_with}' >&2"
          else
            "printf '%s' '#{JSON.generate(reporting)}'"
          end
        File.write(
          "#{bin}/change-writing-lint",
          "#!/bin/sh\nprintf 'arguments:%s\\n' \"$*\" > #{record}\n" \
            "[ \"$#\" -eq 0 ] && cat >> #{record}\n#{output}\n"
        )
        File.chmod(0o755, "#{bin}/change-writing-lint")
        path = ENV.fetch("PATH")
        ENV["PATH"] = "#{bin}:#{path}"
        begin
          yield record
        ensure
          ENV["PATH"] = path
        end
      end
    end
  end
end
