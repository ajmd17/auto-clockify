# frozen_string_literal: true

require 'httparty'
require 'memoist'
require 'json'
require 'date'

require 'autoclockify/clockify/request_builder'

module Autoclockify
  module Clockify
    class Client
      extend Memoist

      CLOCKIFY_API_URL = 'https://api.clockify.me/api/v1'
      REQUEST_FIELDS = {
        workspace_id: 'workspaces',
        user_id: 'user'
      }.freeze

      attr_reader :api_key

      REQUEST_FIELDS.each do |key, value|
        send(:attr_accessor, key)

        define_method(value) do
          perform_request(value, method: :get, options: { workspace: false, user: false })
        end
      end

      def initialize(api_key:)
        @api_key = api_key
      end

      def clock_event(message, start_time: nil, **options)
        verify_workspace_id_set!
        verify_user_id_set!

        start_time ||= if most_recent_entry.nil?
          DateTimeParser.current_workday
        else
          end_time = nil
          loop_count = 0

          loop do
            end_time = most_recent_entry['timeInterval']['end']

            # Currently running, we have to stop the current timer
            break unless end_time.nil?

            stop_timer

            loop_count += 1

            raise 'Failed to stop existing timer before logging entry' if loop_count >= 5
          end

          DateTimeParser.parse(end_time)
        end

        perform_request('time-entries', body: {
          start: start_time,
          end: DateTime.now,
          description: message
        })
      end

      def stop_timer
        verify_workspace_id_set!
        verify_user_id_set!

        perform_request(
          'time-entries',
          body: { end: DateTime.now },
          method: :patch,
          options: { user: true }
        )
      end

      private

        REQUEST_FIELDS.each do |key, value|
          define_method(:"verify_#{key}_set!") do
            raise "#{key} is not set, cannot perform request" unless send(key)
          end
        end

        def most_recent_entry
          resp = perform_request(
            'time-entries',
            method: :get,
            body: {
              start: DateTimeParser.today
            },
            options: {
              user: true
            }
          )

          json = JSON.parse(resp.body)

          return nil if json.empty?

          json.sort_by do |object|
            DateTimeParser.parse(object['timeInterval']['start'])
          end

          json.first
        end

        def perform_request(action, method: :post, body: {}, options: {})
          request_builder = RequestBuilder.new(
            base_url: CLOCKIFY_API_URL,
            api_key: api_key,
            request_fields: REQUEST_FIELDS.keys.each_with_object({}) { |k, h| h[k] = send(k) }
          )

          request_params = request_builder.build(action, method: method, body: body, **options)

          HTTParty.send(method, *request_params).tap do |response|
            raise "Invalid request (#{response.code}): #{response.message}\n#{response.body}" unless response.success?
          end
        end
    end
  end
end
