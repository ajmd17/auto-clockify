# frozen_string_literal: true

require 'memoist'
require 'json'
require 'date'
require 'autoclockify/clockify/date_time_parser'

module Autoclockify
  module Clockify
    class RequestBuilder
      extend Memoist

      attr_reader :base_url
      attr_reader :api_key
      attr_reader :request_fields

      def initialize(base_url:, api_key:, request_fields:)
        @base_url = base_url
        @api_key = api_key
        @request_fields = request_fields
      end

      def build(action, body: {}, method:, **options)
        request_uri = "#{base_url}/#{build_request_uri(action, **options)}"

        body_parsed = body.dup.tap do |body|
          body.each do |key, value|
            body[key] = DateTimeParser.format(value) if value.is_a?(Date)
          end
        end

        result = [request_uri]

        result << if method == :get
          request_options.merge(query: body_parsed)
        else
          request_options.merge(body: JSON.generate(body_parsed))
        end
        
        result
      end

      private

        memoize def request_options
          {
            headers: {
              'X-Api-Key': @api_key,
              'Content-Type': 'application/json'
            }
          }
        end

        def _request_uri_field(options, uri_part, method_name)
          path = []

          method_name_without_id = /(.*)_id$/.match(method_name)[1].to_sym

          return path unless options[method_name_without_id]

          path << uri_part
          path << if options[method_name_without_id] == true
            request_fields[method_name.to_sym]
          else
            options[method_name_without_id]
          end

          path
        end

        def build_request_uri(action, **options)
          merge_options = { workspace: true, user: false }.merge(options)

          path = []

          path << _request_uri_field(merge_options, 'workspaces', 'workspace_id')
          path << _request_uri_field(merge_options, 'user', 'user_id')

          path << action

          path.compact.join('/')
        end
    end
  end
end
