require 'influxdb'

INFLUX_HOST = "10.8.0.1"

influxdb = InfluxDB::Client.new host: INFLUX_HOST, 
  database: "telegraf", 
  time_precision: 's'

str = "Привет123"
data = []
data << {
  series: "test",
  tags: {a: str},
  values: { z: 0 }
}
# puts str.encoding
# puts data.length
# puts data[0][:tags][:a].encode "UTF-8".freeze, "UTF-8".freeze,
      # invalid: :replace,
      # undef: :replace,
      # replace: "".freeze
influxdb.write_points(data)
puts "ok"