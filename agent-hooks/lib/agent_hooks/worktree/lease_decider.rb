module AgentHooks
  module Worktree
    module LeaseDecider
      def self.apply(state, command)
        decide(state, command).each { |event| evolve(state, event) }
      end

      def self.unowned_roots(state)
        state
          .fetch("roots")
          .filter_map do |root, ownership|
            root if ownership.fetch("owners").empty?
          end
      end

      def self.decide(state, command)
        case command
        in { type: :record_activity, session:, at: }
          state
            .fetch("roots")
            .filter_map do |root, ownership|
              if ownership.fetch("owners").key?(session)
                { type: :lease_refreshed, root: root, session: session, at: at }
              end
            end
        in { type: :record_devenv_started, root:, session:, at: }
          [{ type: :lease_claimed, root: root, session: session, at: at }]
        in { type: :expire_leases, before: }
          state
            .fetch("roots")
            .flat_map do |root, ownership|
              ownership
                .fetch("owners")
                .filter_map do |session, seen|
                  if seen < before
                    { type: :lease_expired, root: root, session: session }
                  end
                end
            end
        in { type: :end_session, session: }
          state
            .fetch("roots")
            .keys
            .map do |root|
              { type: :lease_released, root: root, session: session }
            end
        in { type: :remove_root, root: }
          [{ type: :root_removed, root: root }]
        end
      end

      def self.evolve(state, event)
        case event
        in { type: :lease_claimed | :lease_refreshed, root:, session:, at: }
          ownership = state.fetch("roots")[root] ||= { "owners" => {} }
          ownership.fetch("owners")[session] = at
        in { type: :lease_expired | :lease_released, root:, session: }
          state.fetch("roots").fetch(root).fetch("owners").delete(session)
        in { type: :root_removed, root: }
          state.fetch("roots").delete(root)
        end
      end

      private_class_method :decide, :evolve
    end
    private_constant :LeaseDecider
  end
end
