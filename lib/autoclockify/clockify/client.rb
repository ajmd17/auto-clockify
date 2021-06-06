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

      def clock_event(message, start_time:, end_time:, **options)
        verify_workspace_id_set!
        verify_user_id_set!

        perform_request('time-entries', body: {
          start: start_time,
          end: end_time,
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

      def entries_in_range(start_date:, end_date:)
        resp = perform_request(
          'time-entries',
          method: :get,
          body: {
            start: start_date,
            end: end_date
          },
          options: {
            user: true
          }
        )

        JSON.parse(resp.body)
      end

      def most_recent_entry(dt = DateTimeParser.today)
        resp = perform_request(
          'time-entries',
          method: :get,
          body: {
            start: dt
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

      private

        REQUEST_FIELDS.each do |key, value|
          define_method(:"verify_#{key}_set!") do
            raise "#{key} is not set, cannot perform request" unless send(key)
          end
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
