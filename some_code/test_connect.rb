require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'

# INFLUX_HOST = "localhost"
INFLUX_HOST = '10.8.0.1'
TIME_ZONE = 5

@influxdb = InfluxDB::Client.new host: INFLUX_HOST,
  database: "itgrp_listen",
  time_precision: 's'

def read_nps(min_time, max_time)
  named_parameter_query = "SELECT \"z_AuthenticationType\",
                          \"Calling-Station-Id\",
                          \"Class-Ip\",
                          \"z_ClassTime\",
                          \"z_ClassId\",
                          \"Client-Friendly-Name\",
                          \"z_PacketType\",
                          \"SAM-Account-Name\"
                          FROM nps_all
                          WHERE time >= %{1} AND time < %{2}
                                AND \"z_AuthenticationType\"=11"
  res = []
  @influxdb.query named_parameter_query,
                  params: [min_time.to_i*1000000000, max_time.to_i*1000000000] do |name, tags, points|
    points.each do |pt|
      res << pt
      pp pt
      # puts pt['z_PacketType'].class
    end
  end
  # puts (!res.empty?)? "#{res[0]['z_AuthenticationType']}" : "empty"
  puts "[#{Time.now.utc}]: [Read NPS] Readed #{res.length} nps points since #{min_time} to #{max_time}"
  return res
end


@nps_data = read_nps(Time.utc(2016, 11, 4, 14, 0, 0), Time.utc(2016, 11, 4, 15, 0, 0))
