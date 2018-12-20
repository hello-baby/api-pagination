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
        sort_by = options[:sort_by] || column
        raise ArgumentError, "Unknown column: #{column}" unless column_names.include?(column.to_s)
        raise ArgumentError, "Unknown column for sorting: #{sort_by}" unless column_names.include?(sort_by.to_s)

        direction = if options.keys.include?(:middle)
          :middle
        else
          options.keys.include?(:after) ? :after : :before
        end
        cursor_id = options[direction]

        self.total_count = self.count

        if direction == :middle
          left_result = on_cursor(cursor_id, :medium, column)
            .in_direction(:before, sort_by)
            .limit((options[:per_page] || default_per_page) + 1)
          right_result = on_cursor(cursor_id, :after, column)
            .in_direction(:after, sort_by)
            .limit(options[:per_page] || default_per_page)
          ids = left_result.pluck(:id) + right_result.pluck(:id)
          result = where(id: ids).in_direction(:after, sort_by).extending(Cursor::PageScopeMethods)
        else
          result = on_cursor(cursor_id, direction, column)
            .in_direction(direction, sort_by)
            .limit(options[:per_page] || default_per_page)
            .extending(Cursor::PageScopeMethods)
        end
        result.cursor_column = column

        result
      end

      def self.on_cursor(cursor_id, direction, cursor_column)
        if cursor_id.nil?
          where(nil)
        else
          sign = case direction
                 when :medium
                   '<='
                 when :before
                   '<'
                 when :after
                   '>'
                 else
                   raise ArgumentError, "Unknown direction #{direction}"
                 end
          where(["#{self.table_name}.#{cursor_column} #{sign} ?", cursor_id])
        end
      end

      def self.in_direction(direction, sort_by)
        reorder("#{self.table_name}.#{sort_by} #{direction == :after ? 'ASC' : 'DESC'}")
      end
    end
  end
end
