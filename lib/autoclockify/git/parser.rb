# frozen_string_literal: true

require 'memoist'
require 'singleton'
require 'date'

module Autoclockify
  module Git
    class Parser
      extend Memoist
      include Singleton

      instance_eval do
        def method_missing(method, *args)
          instance.send(method, *args)
        end
      end

      def current_branch
        topmost_branch(_branch)
      end

      def commits_in_date_range(start_date:, end_date:)
        commits = _commits_in_range(start_date, end_date)
          .split("\n")
          .map do |line|
            match = /^([a-z0-9]+)\s(.*)$/.match(line)

            {
              hash: match[1],
              detail: match[2],
              command: 'commit'
            }
          end
      end

      def time_of_commit(hash)
        datetime_string = _get_time_of_commit(commit_hash(hash))

        return nil if datetime_string.empty?

        DateTime.parse(datetime_string)
      end

      def last_checkout_into_branch(branch_name)
        regexpr = /moving from (?:.*) to #{branch_name}/

        checkout_ref = reflog.find do |entry|
          entry[:command] == 'checkout' && regexpr =~ entry[:detail]
        end

        return nil if checkout_ref.nil?

        time_of_commit(checkout_ref[:hash])
      end

      def branch_of_commit(hash)
        topmost_branch(_branch_of_commit(commit_hash(hash)))
      end

      def last_commit(include_amend: true, predicate_fn: -> (_){ true })
        allowed_modes = ['initial', ('amend' if include_amend)].compact

        regexpr = /^commit(?:\s\(#{allowed_modes.join('|')}\))?$/ if include_amend

        reflog.find do |entry|
          entry[:command] =~ regexpr && predicate_fn.call(entry)
        end
      end

      memoize def reflog
        _reflog
          .split("\n")
          .map do |entry|
            fields = /(.*)\s(?:(.*):)\s(?:(.*):)\s(.*)/.match(entry)[1..]

            {
              hash: fields[0],
              command: fields[2],
              detail: fields[3]
            }
          end
      end

      private

        def commit_hash(commit_hash_or_ref)
          if commit_hash_or_ref.is_a?(Hash)
            commit_hash_or_ref[:hash]
          else
            commit_hash_or_ref
          end
        end

        def topmost_branch(branches)
          branches = branches.split("\n")

          return nil if branches.empty?

          regexp = /^(?:\*)\s*(.*)$/

          topmost = branches.find { |branch| branch =~ regexp }

          regexp.match(topmost)[1]
        end

        def _commits_in_range(start_date, end_date)
          fmt = '%Y-%m-%d %H:%M'

          `git log --after="#{start_date.strftime(fmt)}" --before="#{end_date.strftime(fmt)}" --pretty="format:%H %s"`
        end

        def _get_time_of_commit(hash)
          `git show -s --format=%ci #{hash}`
        end

        def _branch
          `git branch`
        end

        def _branch_of_commit(hash)
          `git branch -a --contains #{hash}`
        end

        def _reflog
          `git reflog`
        end
    end
  end
end
