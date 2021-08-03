# frozen_string_literal: ture

require 'memoist'

require 'autoclockify/errors'
require 'autoclockify/clockify/client'
require 'autoclockify/clockify/date_time_parser'
require 'autoclockify/git/parser'

module Autoclockify
  class FindEntries
    extend Memoist

    attr_reader :clockify_client
    attr_reader :options
    attr_reader :handler

    def initialize(**options)
      @options = options.dup

      raise 'CLOCKIFY_API_KEY not set in env settings' unless ENV['CLOCKIFY_API_KEY']

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

      raise "no start date provided, provide using --start-date=[date]" unless start_date

      @handler = Handler.new(
        api_key: ENV['CLOCKIFY_API_KEY'],
        clockify_client: @clockify_client,
        clock_commits: options[:clock],
        git_path: options[:path]
      )

      find_entries
    end

    def find_commits
      commits = {}

      (start_date..end_date).each do |day|
        end_of_day = DateTime.new(day.year, day.month, day.day, 23, 59, 59)

        commits[day.strftime('%Y-%m-%d')] = Git::Parser.commits_in_date_range(
          start_date: day,
          end_date: end_of_day
        ).reverse
      end

      commits
    end

    def find_entries
      all_entries = clockify_client.entries_in_range(
        start_date: start_date,
        end_date: end_date
      )

      entries_grouped = all_entries.group_by do |entry|
        Clockify::DateTimeParser.parse(entry['timeInterval']['start']).strftime('%Y-%m-%d')
      end

      find_commits.each do |date_string, commits|
        entries_on_date = entries_grouped[date_string] || []

        datetime = DateTime.strptime(date_string, '%Y-%m-%d')

        commits.each.with_index do |commit, index|
          time_of_commit = Git::Parser.time_of_commit(commit[:hash])

          next_commit = if index < commits.length - 1
            commits[index + 1]
          end

          next_entry = entries_on_date.find do |entry|
            time_of_commit < Clockify::DateTimeParser.parse(entry['timeInterval']['start'])
          end

          handler.handle_commit(
            commit,
            next_entry: next_entry,
            next_commit: next_commit,
            workday: Clockify::DateTimeParser.workday(datetime),
            realtime: false
          )
        end
      end

      handler.display_commits
    end

    memoize def start_date
      options[:start_date] 
    end

    memoize def end_date
      options[:end_date] || DateTime.now
    end

    memoize def clockify_workspace_id
      options[:workspace_id] || ENV['CLOCKIFY_WORKSPACE_ID']
    end

    memoize def clockify_user_id
      options[:user_id] || ENV['CLOCKIFY_USER_ID']
    end
  end
end
