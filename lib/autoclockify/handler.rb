# frozen_string_literal: true
require 'memoist'
require 'autoclockify/git/parser'

module Autoclockify
  class Handler
    extend Memoist

    TEMP_COMMIT_PREFIXES = %w{ tmp temp }.freeze

    attr_reader :api_key
    attr_reader :clockify_client

    def initialize(api_key:, clockify_client:)
      @api_key = api_key
      @clockify_client = clockify_client
    end

    def handle_commit(commit)
      branch_name = Git::Parser.branch_of_commit(commit)
      time_of_checkout = Git::Parser.last_checkout_into_branch(branch_name)

      clockify_client.clock_event(
        commit_message(commit[:detail], commit[:hash]),
        start_time: clockify_start_time(time_of_checkout: time_of_checkout)
      )
    end

    private

      def clockify_start_time(time_of_checkout: nil)
        end_time = stop_current_entry

        [
          Clockify::DateTimeParser.current_workday,
          time_of_checkout,
          (Clockify::DateTimeParser.parse(end_time) unless end_time.nil?)
        ].compact.max
      end

      def stop_current_entry
        # most recent entry is not nil; pull from that; stopping clock if we have to

        loop_count = 0

        loop do
          most_recent = clockify_client.most_recent_entry

          return nil if most_recent.nil?

          end_time = most_recent['timeInterval']['end']

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
