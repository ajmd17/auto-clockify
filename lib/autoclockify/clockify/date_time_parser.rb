# frozen_string_literal: true

require 'memoist'
require 'date'

module Autoclockify
  module Clockify
    class DateTimeParser
      extend Memoist

      TIME_FORMAT_STRING = "%Y-%m-%dT%H:%M:%SZ"

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
    end
  end
end
