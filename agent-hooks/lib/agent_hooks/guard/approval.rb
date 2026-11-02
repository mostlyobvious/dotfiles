require "json"

module AgentHooks
  module Approval
    Message =
      Data.define(:role, :text, :tool_name, :tool_input) do
        def self.from(attributes)
          new(
            role: attributes["role"],
            text: attributes["text"],
            tool_name: attributes["tool_name"],
            tool_input: attributes["tool_input"]
          )
        end
      end

    def self.authorized?(event)
      messages = messages(event)
      go =
        messages.rindex do |message|
          message == Message.from("role" => "user", "text" => "go")
        end
      return false unless go&.positive?

      proposal = messages.fetch(go - 1)
      return false unless proposal&.role == "assistant"

      approval = envelope(proposal.text)
      return false unless approval
      return false unless approval["tool_name"] == event.fetch("tool_name")
      return false unless approval["tool_input"] == event.fetch("tool_input")
      return false unless files_match?(approval.fetch("files", {}))

      pending =
        Message.from(
          "role" => "assistant",
          "tool_name" => event.fetch("tool_name"),
          "tool_input" => event.fetch("tool_input")
        )
      [[], [pending]].include?(messages[(go + 1)..])
    end

    def self.messages(event)
      supplied = event["approval_messages"]
      return supplied.map { |attributes| Message.from(attributes) } if supplied

      path = event["transcript_path"].to_s
      return [] unless File.file?(path)

      File
        .readlines(path, chomp: true)
        .filter_map do |line|
          from_record(JSON.parse(line))
        rescue JSON::ParserError
          nil
        end
    end

    def self.from_record(record)
      message = record.fetch("message", {})
      role = message["role"]
      content = message["content"]
      if content.is_a?(String)
        return Message.from("role" => role, "text" => content)
      end
      return unless content.is_a?(Array)

      text = content.find { |item| item["type"] == "text" }
      return Message.from("role" => role, "text" => text["text"]) if text

      tool =
        content.find { |item| %w[toolCall tool_use].include?(item["type"]) }
      if tool
        return(
          Message.from(
            "role" => role,
            "tool_name" => tool["name"],
            "tool_input" => tool["arguments"] || tool["input"]
          )
        )
      end

      if content.any? { |item| item["type"] == "tool_result" }
        Message.from("role" => "result")
      end
    end

    def self.envelope(text)
      _, marker, payload = text.to_s.partition("Approval:\n```json\n")
      return if marker.empty?

      json, closing, = payload.partition("\n```")
      return if closing.empty?

      JSON.parse(json)
    rescue JSON::ParserError
      nil
    end

    def self.files_match?(files)
      files.all? { |path, content| File.read(path) == content }
    rescue SystemCallError
      false
    end

    private_class_method :messages, :from_record, :envelope, :files_match?
    private_constant :Message
  end
end
