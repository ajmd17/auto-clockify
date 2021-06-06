require 'memoist'
require 'autoclockify/version'
require 'autoclockify/errors'
require 'autoclockify/clockify/client'
require 'autoclockify/git/parser'

module Autoclockify
  class Hooks
    extend Memoist

    TEMP_COMMIT_PREFIXES = %w{ tmp temp }.freeze

    attr_reader :clockify_client
    attr_reader :options

    def initialize(**options)
      @options = options.dup

      raise 'CLOCKIFY_API_KEY not set in env settings' unless ENV['CLOCKIFY_API_KEY']

      hook = options[:hook]
      options.delete(:hook)

      raise 'No hook provided, should be sent as --hook=[git commit hook]' unless hook

      @clockify_client = Clockify::Client.new(
        api_key: ENV['CLOCKIFY_API_KEY']
      )

      raise """
        No workspace id provided. Provide either has --workspace-id=[workspace id] or in env variable CLOCKIFY_WORKSPACE_ID.\n
        Available workspaces:\n\n#{@clockify_client.workspaces.map { |item| "#{item['name']}:\t#{item['id']}" }.join("\n")}
      """ unless clockify_workspace_id

      @clockify_client.workspace_id = clockify_workspace_id

      raise """
        No user id provided. Provide either has --user-id=[user id] or in env variable CLOCKIFY_USER_ID.\n
        Currently logged in user:\n\n#{@clockify_client.user['name']}:\t#{@clockify_client.user['id']}
      """ unless clockify_user_id

      @clockify_client.user_id = clockify_user_id

      send(:"on_#{hook}", **options)
    end

    def method_missing(m, *args, &block)
      raise HookNotDefinedError.new(/^on_(.*)/.match(m.to_s)[1], methods.grep(/^on_/)) if m.to_s =~ /^on_/

      super
    end

    def on_post_commit(**)
      last_commit = Git::Parser.last_commit
      branch_name = Git::Parser.branch_of_commit(last_commit)
      time_of_checkout = Git::Parser.last_checkout_into_branch(branch_name)

      clockify_client.clock_event(
        commit_message(last_commit[:detail], last_commit[:hash]),
        start_time: clockify_start_time(time_of_checkout: time_of_checkout)
      )
    end

    private

      memoize def clockify_workspace_id
        options[:workspace_id] || ENV['CLOCKIFY_WORKSPACE_ID']
      end

      memoize def clockify_user_id
        options[:user_id] || ENV['CLOCKIFY_USER_ID']
      end

      def clockify_start_time(time_of_checkout: nil)
        end_time = stop_current_entry

        [
          Clockify::DateTimeParser.current_workday,
          time_of_checkout,
          Clockify::DateTimeParser.parse(end_time)
        ].max
      end

      def stop_current_entry
        # most recent entry is not nil; pull from that; stopping clock if we have to

        loop_count = 0

        loop do
          end_time = clockify_client.most_recent_entry['timeInterval']['end']

          return end_time unless end_time.nil?

          clockify_client.stop_timer

          loop_count += 1

          raise 'Failed to stop existing timer before logging entry' if loop_count >= 5
        end
      end

      def commit_message(commit_message, hash = nil)
        if temp_commit?(commit_message)
          # Strip the "TMP" or "TEMP" part out
          stripped_commit_message = commit_message.gsub(/((?:#{TEMP_COMMIT_PREFIXES.join('|')})\s+)/i, '')
          stripped_commit_message_without_ticket = stripped_commit_message.gsub(/^(([a-zA-Z]+-\d+)\s+)/, '')

          commit_message = if stripped_commit_message.empty? || stripped_commit_message_without_ticket.empty?
            entry_name_from_branch(hash)
          else
            stripped_commit_message
          end.capitalize
        end

        commit_message
      end

      # For temp commits, create the entry name using the branch name
      def entry_name_from_branch(commit_hash = nil)
        branch_name = if commit_hash.nil?
          Git::Parser.current_branch
        else
          Git::Parser.branch_of_commit(commit_hash)
        end

        branch_name.tr('-', ' ')
      end

      def humanize_branch_name(branch_name)
        branch_name
      end

      def temp_commit?(message)
        message_downcase = message.downcase

        TEMP_COMMIT_PREFIXES.each do |prefix|
          return true if (message_downcase =~ /(?:([a-zA-Z]+-\d+)\s+)?(#{prefix})/) == 0
        end

        false
      end
  end
end
