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

      require 'byebug'; byebug

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
      @clockify_client.start_of_day = ENV['START_OF_DAY'].to_i if ENV['START_OF_DAY'].to_s != ''

      send(:"on_#{hook}", **options)
    end

    def method_missing(m, *args, &block)
      raise HookNotDefinedError.new(/^on_(.*)/.match(m.to_s)[1], methods.grep(/^on_/)) if m.to_s =~ /^on_/

      super
    end
    
    def on_commit_msg(**options)
      commit_message = options[:commit_message]

      raise 'No commit message provided' unless commit_message

      if temp_commit?(commit_message)
        # find a last commit that has message equaling the one we were given
        last_commit_matching = Git::Parser.last_commit(predicate_fn: -> (entry){
          entry[:detail] == commit_message
        })

        if last_commit_matching.nil?
          puts "WARNING: No commit found in reflog matching commit message."
        else
          branch_name = Git::Parser.branch_of_commit(last_commit_matching)
          

          # commit_message = commit_message_from_branch_name()
        end

        require 'byebug'; byebug
      end

      clockify_client.clock_event(commit_message)
    end

    def on_post_checkout(**options)
      ref = Git::Parser.last_commit


    end

    def on_post_commit(**)
      # no-op
    end

    private

      memoize def clockify_workspace_id
        options[:workspace_id] || ENV['CLOCKIFY_WORKSPACE_ID']
      end

      memoize def clockify_user_id
        options[:user_id] || ENV['CLOCKIFY_USER_ID']
      end

      def temp_commit?(message)
        message_downcase = message.downcase

        TEMP_COMMIT_PREFIXES.each do |prefix|
          return true if (message_downcase =~ /(?:([a-zA-Z]+-\d+)\s)?(#{prefix})/) == 0
        end

        false
      end
  end
end
