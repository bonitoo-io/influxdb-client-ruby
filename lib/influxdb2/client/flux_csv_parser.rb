# The MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
require 'csv'
require 'base64'
require 'time'

module InfluxDB2
  # This class represents Flux query error
  #
  class FluxQueryError < StandardError
    def initialize(message, reference)
      super(message)
      @reference = reference
    end

    attr_reader :reference
  end

  # This class represents Flux query error
  #
  class FluxCsvParserError < StandardError
    def initialize(message)
      super(message)
    end
  end

  # This class us used to construct FluxResult from CSV.
  #
  class FluxCsvParser
    include Enumerable
    def initialize(response, stream: false)
      @response = response
      @stream = stream
      @tables = {}

      @table_index = 0
      @table_id = -1
      @start_new_table = false
      @table = nil
      @groups = []
      @parsing_state_error = false

      @closed = false
    end

    attr_reader :tables, :closed

    def parse
      @csv_file = CSV.new(@response.instance_of?(Net::HTTPOK) ? @response.body : @response)

      while (csv = @csv_file.shift)
        # Response has HTTP status ok, but response is error.
        next if csv.empty?

        if csv[1] == 'error' && csv[2] == 'reference'
          @parsing_state_error = true
          next
        end

        # Throw  InfluxException with error response
        if @parsing_state_error
          error = csv[1]
          reference_value = csv[2]
          raise FluxQueryError.new(error, reference_value.nil? || reference_value.empty? ? 0 : reference_value.to_i)
        end

        result = _parse_line(csv)

        yield result if @stream && result.instance_of?(InfluxDB2::FluxRecord)
      end

      self
    end

    def each
      return enum_for(:each) unless block_given?

      parse do |record|
        yield record
      end

      self
    ensure
      _close_connection
    end

    private

    ANNOTATION_DATATYPE = '#datatype'.freeze
    ANNOTATION_GROUP = '#group'.freeze
    ANNOTATION_DEFAULT = '#default'.freeze
    ANNOTATIONS = [ANNOTATION_DATATYPE, ANNOTATION_GROUP, ANNOTATION_DEFAULT].freeze

    def _parse_line(csv)
      token = csv[0]

      # start new table
      if (ANNOTATIONS.include? token) && !@start_new_table
        # Return already parsed DataFrame
        @start_new_table = true
        @table = InfluxDB2::FluxTable.new
        @groups = []

        @tables[@table_index] = @table unless @stream

        @table_index += 1
        @table_id = -1
      elsif @table.nil?
        raise FluxCsvParserError, 'Unable to parse CSV response. FluxTable definition was not found.'
      end

      #  # datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,dateTime:RFC3339,double,string,string,string
      if token == ANNOTATION_DATATYPE
        _add_data_types(@table, csv)

      elsif token == ANNOTATION_GROUP
        @groups = csv

      elsif token == ANNOTATION_DEFAULT
        _add_default_empty_values(@table, csv)
      else
        _parse_values(csv)
      end
    end

    def _add_data_types(table, data_types)
      (1..data_types.length - 1).each do |index|
        column_def = InfluxDB2::FluxColumn.new(index: index - 1, data_type: data_types[index])
        table.columns.push(column_def)
      end
    end

    def _add_groups(table, csv)
      i = 1

      table.columns.each do |column|
        column.group = csv[i] == 'true'
        i += 1
      end
    end

    def _add_default_empty_values(table, default_values)
      i = 1

      table.columns.each do |column|
        column.default_value = default_values[i]
        i += 1
      end
    end

    def _add_column_names_and_tags(table, csv)
      i = 1

      table.columns.each do |column|
        column.label = csv[i]
        i += 1
      end
    end

    def _parse_values(csv)
      # parse column names
      if @start_new_table
        _add_groups(@table, @groups)
        _add_column_names_and_tags(@table, csv)
        @start_new_table = false
        return
      end

      current_id = csv[2].to_i
      @table_id = current_id if @table_id == -1

      if @table_id != current_id
        # create new table with previous column headers settings
        @flux_columns = @table.columns
        @table = InfluxDB2::FluxTable.new

        @flux_columns.each do |column|
          @table.columns.push(column)
        end

        @tables[@table_index] = @table unless @stream
        @table_index += 1
        @table_id = current_id
      end

      flux_record = _parse_record(@table_index - 1, @table, csv)

      if @stream
        flux_record
      else
        @tables[@table_index - 1].records.push(flux_record)
      end
    end

    def _parse_record(table_index, table, csv)
      record = InfluxDB2::FluxRecord.new(table_index)

      table.columns.each do |flux_column|
        column_name = flux_column.label
        str_val = csv[flux_column.index + 1]
        record.values[column_name] = _to_value(str_val, flux_column)
      end

      record
    end

    def _to_value(str_val, column)
      if str_val.nil? || str_val.empty?
        default_value = column.default_value

        return nil if default_value.nil? || default_value.empty?

        _to_value(default_value, column)
      end

      case column.data_type
      when 'boolean'
        if str_val.nil? || str_val.empty?
          true
        else
          str_val.casecmp('true').zero?
        end
      when 'unsignedLong', 'long', 'duration'
        str_val.to_i
      when 'double'
        case str_val
        when '+Inf'
          Float::INFINITY
        when '-Inf'
          -Float::INFINITY
        else
          str_val.to_f
        end
      when 'base64Binary'
        Base64.decode64(str_val)
      when 'dateTime:RFC3339', 'dateTime:RFC3339Nano'
        Time.parse(str_val).to_datetime.rfc3339(9)
      else
        str_val
      end
    end

    def _close_connection
      # Close CSV Parser
      @csv_file.close
      @closed = true
    end
  end
end
