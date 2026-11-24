require_relative "../support/guard_helpers"

module AgentHooks
  class ColdReadPolicyTest < Minitest::Test
    include GuardHelpers
    cover "AgentHooks::Guard::Policies::ColdRead*"
    cover "AgentHooks::Guard::Facts.observe"
    cover "AgentHooks::Guard::Facts.cold_read?"

    def test_description_no_fresh_reader_has_read_is_blocked
      with_description do |description|
        assert_equal cold_read_blocked(description),
                     call("mr-describe 42 #{description}", change_writing: true)
      end
    end

    def test_description_a_fresh_reader_has_read_is_published
      with_description do |description|
        assert_equal [0, ""],
                     call(
                       "mr-describe 42 #{description}",
                       change_writing: true,
                       cold_read: [description]
                     )
      end
    end

    def test_reading_another_file_does_not_count
      with_description do |description|
        assert_equal cold_read_blocked(description),
                     call(
                       "mr-describe 42 #{description}",
                       change_writing: true,
                       cold_read: ["#{description}.bak"]
                     )
      end
    end

    def test_an_edit_after_the_read_needs_another_read
      published_after(%w[read Edit skill]) do |result, description|
        assert_equal cold_read_blocked(description), result
      end
    end

    def test_a_rewrite_after_the_read_needs_another_read
      published_after(%w[read Write skill]) do |result, description|
        assert_equal cold_read_blocked(description), result
      end
    end

    def test_a_read_after_the_latest_edit_is_current
      published_after(%w[read Edit read skill]) do |result, _|
        assert_equal [0, ""], result
      end
    end

    def test_an_edit_to_another_file_keeps_the_read
      with_description do |description|
        with_session do |home, session|
          cold_read(home, session, description)
          observe(home, session, "Edit", file_path: "#{description}.bak")
          change_writing(home, session)
          merge_request(home, session)

          assert_equal [0, ""],
                       call(
                         "mr-describe 42 #{description}",
                         home: home,
                         session_id: session
                       )
        end
      end
    end

    def test_a_read_in_a_command_chain_counts
      with_description do |description|
        with_session do |home, session|
          observe(
            home,
            session,
            "Bash",
            command: "printf start && mr-cold-read #{description} | tee out"
          )
          change_writing(home, session)
          merge_request(home, session)

          assert_equal [0, ""],
                       call(
                         "mr-describe 42 #{description}",
                         home: home,
                         session_id: session
                       )
        end
      end
    end

    def test_a_relative_read_resolves_against_its_working_directory
      with_description do |description|
        with_session do |home, session|
          cold_read(
            home,
            session,
            File.basename(description),
            cwd: File.dirname(description)
          )
          change_writing(home, session)
          merge_request(home, session)

          assert_equal [0, ""],
                       call(
                         "mr-describe 42 #{description}",
                         home: home,
                         session_id: session
                       )
        end
      end
    end

    def test_a_read_without_a_file_records_nothing
      with_description do |description|
        with_session do |home, session|
          observe(home, session, "Bash", command: "mr-cold-read")
          change_writing(home, session)
          merge_request(home, session)

          assert_equal cold_read_blocked(description),
                       call(
                         "mr-describe 42 #{description}",
                         home: home,
                         session_id: session
                       )
        end
      end
    end

    def test_every_unread_description_is_named
      with_description do |first|
        with_description do |second|
          command = "mr-describe 42 #{first} && mr-describe 43 #{second}"

          assert_equal cold_read_blocked(first, second),
                       call(command, change_writing: true)
        end
      end
    end

    def test_only_the_unread_description_is_named
      with_description do |first|
        with_description do |second|
          command = "mr-describe 42 #{first} && mr-describe 43 #{second}"

          assert_equal cold_read_blocked(second),
                       call(command, change_writing: true, cold_read: [first])
        end
      end
    end

    def test_every_description_read_is_remembered
      with_description do |first|
        with_description do |second|
          command = "mr-describe 42 #{first} && mr-describe 43 #{second}"

          assert_equal [0, ""],
                       call(
                         command,
                         change_writing: true,
                         cold_read: [first, second]
                       )
        end
      end
    end

    def test_a_commit_before_an_unread_description_does_not_hide_it
      with_description do |description|
        with_commit_message("Document hook policy\n") do |message|
          command = "git commit -F #{message} && mr-describe 42 #{description}"

          assert_equal cold_read_blocked(description),
                       call(command, change_writing: true)
        end
      end
    end

    def test_description_file_of_a_creating_script_needs_a_read
      with_description do |description|
        script = "#{File.dirname(description)}/open.sh"
        File.write(
          script,
          "glab mr create --squash-before-merge=false --description-file #{description}\n"
        )

        assert_equal cold_read_blocked(description),
                     call(script, change_writing: true)
      end
    end

    def test_commit_message_needs_no_read
      with_commit_message("Document hook policy\n") do |path|
        assert_equal [0, ""],
                     call("git commit -F #{path}", change_writing: true)
      end
    end

    def test_missing_description_needs_no_read
      assert_equal [0, ""],
                   call("mr-describe 42 /tmp/missing.md", change_writing: true)
    end

    private

    def with_description
      Dir.mktmpdir do |directory|
        description = "#{File.realpath(directory)}/mr-description.md"
        File.write(description, "The importer stops at the first bad row.\n")
        yield description
      end
    end

    def published_after(steps)
      with_description do |description|
        with_session do |home, session|
          merge_request(home, session)
          steps.each do |step|
            case step
            when "read"
              cold_read(home, session, description)
            when "skill"
              change_writing(home, session)
            else
              observe(home, session, step, file_path: description)
            end
          end

          yield(
            call(
              "mr-describe 42 #{description}",
              home: home,
              session_id: session
            ),
            description
          )
        end
      end
    end
  end
end
