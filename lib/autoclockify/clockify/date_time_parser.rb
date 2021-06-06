# frozen_string_literal: true

require 'memoist'
require 'date'

module Autoclockify
  module Clockify
    class DateTimeParser
      extend Memoist

      TIME_FORMAT_STRING = "%Y-%m-%dT%H:%M:%SZ"

      def self.current_workday
        _today = today

        DateTime.new(_today.year, _today.month, _today.day, start_of_day, 0, 0, 0)
      end

      def self.today
        _now = DateTime.now

        DateTime.new(_now.year, _now.month, _now.day, 0, 0, 0, 0)
      end

      def self.parse(datetime_string)
        DateTime.strptime(datetime_string, TIME_FORMAT_STRING)
      end

      def self.format(datetime)
        datetime.new_offset(0).strftime(TIME_FORMAT_STRING)
      end

      private

        def self.start_of_day
          return ENV['START_OF_DAY'].to_i if ENV['START_OF_DAY'].to_s != ''

          9
        end
    end
  end
end
