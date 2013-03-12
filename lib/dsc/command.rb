require "progressbar"
require "csv"

module Dsc

  class Command

    def self.transport_class
      nil
    end

    def self.schema
      result = {}
      transport_class.mappings.each { |key, value| result[key] = value.description }
      result
    end

    def initialize(global_options)
      @hostname = global_options[:m]
      @port = global_options[:port].to_i
      @tenant = global_options[:t]
      @username =global_options[:u]
      @password = global_options[:p]
      @show_progress_bar = global_options[:P]
      @debug_level = debug_level_from_option(global_options[:d])
      @output = global_options[:o]
    end

    def self.default_fields
      []
    end

    def self.default_fields_string
      default_fields.join(",")
    end

    def self.valid_fields
      transport_class.defined_attributes.sort
    end

    def parse_fields(string)
      fields = string.split(",").map(&:strip)
      unknown_fields = fields.reject { |each| self.class.transport_class.has_attribute_chain(each) }
      raise "Unknown field found (#{unknown_fields.join(', ')}) - known fields are: #{self.class.valid_fields.join(', ')}" unless unknown_fields.empty?
      fields
    end

    def self.valid_time_filters
      {
          :last_hour => DeepSecurity::TimeFilter.last_hour,
          :last_24_hours => DeepSecurity::TimeFilter.last_24_hours,
          :last_7_days => DeepSecurity::TimeFilter.last_7_days,
          :last_day => DeepSecurity::TimeFilter.last_day
      }
    end

    def self.valid_time_filters_string
      valid_time_filters.keys.join(', ')
    end

    def parse_time_filter(string)
      filter = self.class.valid_time_filters[string.to_sym]
      raise "Unknown time filter" if filter.nil?
      filter
    end


    def debug_level_from_option(option)
      return nil if option.blank?
      return option.to_sym if (DeepSecurity::LOG_MAPPING.keys.include?(option.to_sym))
      :debug
    end

    def output
      unless @output == '--'
        output = File.open(option, 'w')
      else
        output = STDOUT
      end
      yield output
      output.close() unless @output == '--'
    end

    def connect
      yield DeepSecurity::Manager.server(@hostname, @port, @debug_level)
    end

    def authenticate
      connect do |dsm|
        begin
          dsm.connect(@tenant, @username, @password)
          yield dsm
        rescue DeepSecurity::AuthenticationFailedException => e
          puts "Authentication failed! #{e.message}"
        ensure
          dsm.disconnect()
        end
      end
    end


    def print_api_version(options, args)
      output do |output|
        authenticate do |dsm|
          output.puts dsm.api_version()
        end
      end
    end

    def print_manager_time(options, args)
      output do |output|
        authenticate do |dsm|
          output.puts dsm.manager_time()
        end
      end
    end

    def print_schema(options, args)
      output do |output|
        schema = self.class.schema()
        schema.keys.sort.each do |key|
          output.puts "#{key}: #{schema[key]}"
        end
      end
    end

  end

end