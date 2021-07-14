# The MIT
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

require 'test_helper'

class FluxCsvParserTest < MiniTest::Test
  def test_multiple_values
    data = "#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,string,string,string,string,long,long,string\n" \
      "#group,false,false,true,true,true,true,true,true,false,false,false\n" \
      "#default,_result,,,,,,,,,,\n" \
      ",result,table,_start,_stop,_field,_measurement,host,region,_value2,value1,value_str\n" \
      ",,0,1677-09-21T00:12:43.145224192Z,2018-07-16T11:21:02.547596934Z,free,mem,A,west,121,11,test\n" \
      ",,1,1677-09-21T00:12:43.145224192Z,2018-07-16T11:21:02.547596934Z,free,mem,B,west,484,22,test\n" \
      ",,2,1677-09-21T00:12:43.145224192Z,2018-07-16T11:21:02.547596934Z,usage_system,cpu,A,west,1444,38,test\n" \
      ',,3,1677-09-21T00:12:43.145224192Z,2018-07-16T11:21:02.547596934Z,user_usage,cpu,A,west,2401,49,test'

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables

    column_headers = tables[0].columns
    assert_equal 11, column_headers.size

    values = [false, false, true, true, true, true, true, true, false, false, false]
    _assert_columns(column_headers, values: values)
    assert_equal 4, tables.size

    _assert_multiple_record(tables)
  end

  def test_parse_shortcut
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,boolean\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,true\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,true\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables

    assert_equal 1, tables.size
    assert_equal 1, tables[0].records.size

    record = tables[0].records[0]

    assert_equal _parse_time('1970-01-01T00:00:10Z'), record.start
    assert_equal _parse_time('1970-01-01T00:00:20Z'), record.stop
    assert_equal _parse_time('1970-01-01T00:00:10Z'), record.time
    assert_equal 10, record.value
    assert_equal 'free', record.field
    assert_equal 'mem', record.measurement
  end

  def test_mapping_boolean
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,boolean\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,true\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,true\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,false\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,x\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal true, records[0].values['value']
    assert_equal false, records[1].values['value']
    assert_equal false, records[2].values['value']
    assert_equal true, records[3].values['value']
  end

  def test_mapping_unsigned_long
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,unsignedLong\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,17916881237904312345\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    expected = 17_916_881_237_904_312_345

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal expected, records[0].values['value']
    assert_nil records[1].values['value']
  end

  def test_mapping_double
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,double\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,12.25\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n" \

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal 12.25, records[0].values['value']
    assert_nil records[1].values['value']
  end

  def test_mapping_base64_binary
    binary_data = 'test value'
    encoded_data = Base64.encode64(binary_data)

    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,base64Binary\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ',,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,' + encoded_data + "\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    value = records[0].values['value']

    assert !value.nil?
    assert_equal binary_data, value

    assert_nil records[1].values['value']
  end

  def test_mapping_rfc3339
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,dateTime:RFC3339\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,1970-01-01T00:00:10Z\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal _parse_time('1970-01-01T00:00:10Z'), records[0].values['value']
    assert_nil records[1].values['value']
  end

  def test_mapping_rfc3339_nano
    data = "#group,false,false,true,true,false,false,true,true,true,true,true,true\n" \
      '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,dateTime:RFC3339,double,' \
      "string,string,string,string,string,string\n" \
      "#default,mean,,,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,language,license,name,owner\n" \
      ',,0,2020-11-02T07:29:49.55050738Z,2020-12-02T07:29:49.55050738Z,2020-11-02T09:00:00Z,9,' \
      "stars,gh,Ruby,MIT,influxdb-client-ruby,influxdata\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal 9, records[0].values['_value']
    start = Time.parse(records[0].values['_start'])
    assert_equal 2020, start.year
    assert_equal 11, start.month
    assert_equal 2, start.day
    assert_equal 7, start.hour
    assert_equal 29, start.min
    assert_equal 49, start.sec
    assert_equal '55050738', start.strftime('%8N')
  end

  def test_mapping_duration
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339' \
      ",dateTime:RFC3339,long,string,string,string,duration\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,125\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal 125, records[0].values['value']
    assert_nil records[1].values['value']
  end

  def test_group_key
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,duration\n" \
      "#group,false,false,false,false,true,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,125\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n" \

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables

    assert_equal 10, tables[0].columns.size
    assert_equal 2, tables[0].group_key.size
  end

  def test_unknown_type_as_string
    data = '#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,' \
      "dateTime:RFC3339,long,string,string,string,unknown\n" \
      "#group,false,false,false,false,false,false,false,false,false,true\n" \
      "#default,_result,,,,,,,,,\n" \
      ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,12.25\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    records = tables[0].records

    assert_equal '12.25', records[0].values['value']
    assert_nil records[1].values['value']
  end

  private

  def _parse_time(time)
    Time.parse(time).to_datetime.rfc3339(9)
  end

  def _assert_record(flux_record, values: nil, size: 0, value: nil)
    values.keys.each do |key|
      assert_equal values[key], flux_record.values[key]
    end

    if value.nil?
      assert_nil value
    else
      assert_equal value, flux_record.value
    end

    assert_equal size, flux_record.values.size
  end

  def _assert_columns(column_headers, values: nil)
    i = 0
    values.each do |value|
      assert_equal value, column_headers[i].group
      i += 1
    end
  end

  def _assert_multiple_record(tables)
    # Record 1
    table_records = tables[0].records
    assert_equal 1, table_records.size

    values = { 'table' => 0, 'host' => 'A', 'region' => 'west', 'value1' => 11, '_value2' => 121,
               'value_str' => 'test' }

    _assert_record(table_records[0], values: values, size: 11)

    # Record 2
    table_records = tables[1].records
    assert_equal 1, table_records.size

    values = { 'table' => 1, 'host' => 'B', 'region' => 'west', 'value1' => 22, '_value2' => 484,
               'value_str' => 'test' }

    _assert_record(table_records[0], values: values, size: 11)

    # Record 3
    table_records = tables[2].records
    assert_equal 1, table_records.size

    values = { 'table' => 2, 'host' => 'A', 'region' => 'west', 'value1' => 38, '_value2' => 1444,
               'value_str' => 'test' }

    _assert_record(table_records[0], values: values, size: 11)

    # Record 4
    table_records = tables[3].records
    assert_equal 1, table_records.size

    values = { 'table' => 3, 'host' => 'A', 'region' => 'west', 'value1' => 49, '_value2' => 2401,
               'value_str' => 'test' }

    _assert_record(table_records[0], values: values, size: 11)
  end
end

class FluxCsvParserErrorTest < MiniTest::Test
  def test_error
    data = "#datatype,string,string\n" \
      "#group,true,true\n" \
      "#default,,\n" \
      ",error,reference\n" \
      ',failed to create physical plan: invalid time bounds from procedure from: bounds contain zero time,897'

    parser = InfluxDB2::FluxCsvParser.new(data)

    error = assert_raises InfluxDB2::FluxQueryError do
      parser.parse
    end

    assert_equal 'failed to create physical plan: invalid time bounds from procedure from: bounds contain zero time',
                 error.message
    assert_equal 897, error.reference
  end

  def test_error_without_reference
    data = "#datatype,string,string\n" \
      "#group,true,true\n" \
      "#default,,\n" \
      ",error,reference\n" \
      ',failed to create physical plan: invalid time bounds from procedure from: bounds contain zero time,'

    parser = InfluxDB2::FluxCsvParser.new(data)

    error = assert_raises InfluxDB2::FluxQueryError do
      parser.parse
    end

    assert_equal 'failed to create physical plan: invalid time bounds from procedure from: bounds contain zero time',
                 error.message
    assert_equal 0, error.reference
  end

  def test_without_table_definition
    data = ",result,table,_start,_stop,_time,_value,_field,_measurement,host,value\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,12.25\n" \
      ",,0,1970-01-01T00:00:10Z,1970-01-01T00:00:20Z,1970-01-01T00:00:10Z,10,free,mem,A,\n"

    parser = InfluxDB2::FluxCsvParser.new(data)

    error = assert_raises InfluxDB2::FluxCsvParserError do
      parser.parse
    end

    assert_equal 'Unable to parse CSV response. FluxTable definition was not found.', error.message
  end

  def test_response_with_error
    data = "#datatype,string,long,string,string,dateTime:RFC3339,dateTime:RFC3339,dateTime:RFC3339,double,string\n" \
    "#group,false,false,true,true,true,true,false,false,true\n" \
    "#default,t1,,,,,,,,\n" \
    ",result,table,_field,_measurement,_start,_stop,_time,_value,tag\n" \
    ",,0,value,python,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test1\n" \
    ",,0,value,python,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test1\n" \
    ",,0,value,python,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test1\n" \
    ",,0,value,python,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test1\n" \
    "\n" \
    "#datatype,string,string\n" \
    "#group,true,true\n" \
    "#default,,\n" \
    ",error,reference\n" \
    ',"engine: unknown field type for value: xyz",'

    parser = InfluxDB2::FluxCsvParser.new(data)

    error = assert_raises InfluxDB2::FluxQueryError do
      parser.parse
    end

    assert_equal 'engine: unknown field type for value: xyz', error.message
    assert_equal 0, error.reference
  end

  def test_multiple_queries
    data = "#datatype,string,long,string,string,dateTime:RFC3339,dateTime:RFC3339,dateTime:RFC3339,double,string\n" \
      "#group,false,false,true,true,true,true,false,false,true\n" \
       "#default,t1,,,,,,,,\n" \
       ",result,table,_field,_measurement,_start,_stop,_time,_value,tag\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:26:40Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:28:20Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:30:00Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:26:40Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:28:20Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:30:00Z,2,test2\n" \
       "\n" \
       "#datatype,string,long,string,string,dateTime:RFC3339,dateTime:RFC3339,dateTime:RFC3339,double,string\n" \
       "#group,false,false,true,true,true,true,false,false,true\n" \
       "#default,t2,,,,,,,,\n" \
       ",result,table,_field,_measurement,_start,_stop,_time,_value,tag\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:26:40Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:28:20Z,2,test1\n" \
       ",,0,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:30:00Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:26:40Z,2,test2\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:28:20Z,2,test2\n" \
       ',,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:30:00Z,2,test2'

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables

    assert_equal 4, tables.size
    assert_equal 7, tables[0].records.size
    assert_equal 7, tables[1].records.size
    assert_equal 7, tables[2].records.size
    assert_equal 7, tables[3].records.size
  end

  def test_table_not_start_at_zero
    data = "#datatype,string,long,string,string,dateTime:RFC3339,dateTime:RFC3339,dateTime:RFC3339,double,string\n" \
       "#group,false,false,true,true,true,true,false,false,true\n" \
       "#default,t1,,,,,,,,\n" \
       ",result,table,_field,_measurement,_start,_stop,_time,_value,tag\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:26:40Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:28:20Z,2,test1\n" \
       ",,1,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:30:00Z,2,test1\n" \
       ",,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:20:00Z,2,test2\n" \
       ",,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:21:40Z,2,test2\n" \
       ",,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:23:20Z,2,test2\n" \
       ",,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:25:00Z,2,test2\n" \
       ",,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:26:40Z,2,test2\n" \
       ",,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:28:20Z,2,test2\n" \
       ',,2,value,pct,2010-02-27T04:48:32.752600083Z,2020-02-27T16:48:32.752600083Z,2020-02-27T16:30:00Z,2,test2\n'

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables

    assert_equal 2, tables.size
    assert_equal 7, tables[0].records.size
    assert_equal 7, tables[1].records.size
  end

  def test_parse_export_from_ui
    data = "#group,false,false,true,true,true,true,true,true,false,false\n" \
   "#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,string,string,string,string,double,dateTime:RFC3339\n" \
   "#default,mean,,,,,,,,,\n" \
   ",result,table,_start,_stop,_field,_measurement,city,location,_value,_time\n" \
   ",,0,1754-06-26T11:30:27.613654848Z,2040-10-27T12:13:46.485Z,temp,weather,Lon,us,30,1975-09-01T16:59:54.5Z\n" \
   ",,1,1754-06-26T11:30:27.613654848Z,2040-10-27T12:13:46.485Z,temp,weather,Lon,us,86,1975-09-01T16:59:54.5Z\n"

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    assert_equal 2, tables.size
    assert_equal 1, tables[0].records.size
    assert_equal false, tables[0].columns[0].group
    assert_equal false, tables[0].columns[1].group
    assert_equal true, tables[0].columns[2].group
    assert_equal 1, tables[1].records.size
  end

  def test_parse_infinity
    data = '#group,false,false,true,true,true,true,true,true,true,true,false,false
#datatype,string,long,dateTime:RFC3339,dateTime:RFC3339,string,string,string,string,string,string,double,double
#default,_result,,,,,,,,,,,
,result,table,_start,_stop,_field,_measurement,language,license,name,owner,le,_value
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,0,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,10,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,20,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,30,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,40,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,50,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,60,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,70,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,80,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,90,0
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,+Inf,15
,,0,2021-06-23T06:50:11.897825012Z,2021-06-25T06:50:11.897825012Z,stars,gh,C#,MIT,ruby,influxdata,-Inf,15'

    tables = InfluxDB2::FluxCsvParser.new(data).parse.tables
    assert_equal 1, tables.size
    assert_equal 12, tables[0].records.size
    assert_equal tables[0].records[10].values['le'], Float::INFINITY
    assert_equal tables[0].records[11].values['le'], -Float::INFINITY
  end
end
