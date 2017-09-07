require_relative 'config'
require_relative 'configuration_methods'
require_relative 'page_scope_methods'

module Cursor
  module ActiveRecordModelExtension
    extend ActiveSupport::Concern

    class_methods do
      cattr_accessor :total_count
    end

    included do
      self.send(:include, Cursor::ConfigurationMethods)

      def self.cursor_page(options = {})
        options.to_hash.symbolize_keys!
        column = options.fetch(:column, :id)
        raise ArgumentError, "Unknown column: #{column}" unless column_names.include?(column.to_s)

        direction = options.keys.include?(:after) ? :after : :before
        cursor_id = options[direction]

        self.total_count = self.count

        result = on_cursor(cursor_id, direction, column)
          .in_direction(direction, column)
          .limit(options[:per_page] || default_per_page)
          .extending(Cursor::PageScopeMethods)

        result.cursor_column = column
        result
      end

      def self.on_cursor(cursor_id, direction, cursor_column)
        if cursor_id.nil?
          where(nil)
        else
          where(["#{self.table_name}.#{cursor_column} #{direction == :after ? '>' : '<'} ?", cursor_id])
        end
      end

      def self.in_direction(direction, cursor_column)
        reorder("#{self.table_name}.#{cursor_column} #{direction == :after ? 'ASC' : 'DESC'}")
      end
    end
  end
end
