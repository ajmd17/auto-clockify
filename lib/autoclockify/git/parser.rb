# frozen_string_literal: true

require 'memoist'
require 'singleton'

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

      def branch_of_commit(commit_hash_or_ref)
        commit_hash = if commit_hash_or_ref.is_a?(Hash)
          commit_hash_or_ref[:hash]
        else
          commit_hash_or_ref
        end

        topmost_branch(_branch_of_commit(commit_hash))
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
              revision: fields[1],
              command: fields[2],
              detail: fields[3]
            }
          end
      end

      private

        def topmost_branch(branches)
          branches = branches.split("\n")

          return nil if branches.empty?

          regexp = /^(?:\*\s)(.*)$/

          topmost = branches.find { |branch| branch =~ regexp }

          regexp.match(topmost)[1]
        end

        def _branch
          `git branch`
        end

        def _branch_of_commit(commit_hash)
          `git branch -a --contains #{commit_hash}`
        end

        def _reflog
          `git reflog`
        end
    end
  end
end
