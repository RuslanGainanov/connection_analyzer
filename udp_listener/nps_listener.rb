require 'socket'
require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'

INFLUX_HOST = "localhost"
NPS_LISTEN_PORT = 5241
NPS_LISTEN_ADDR = "0.0.0.0"
TIME_ZONE = 5

@influxdb = InfluxDB::Client.new host: INFLUX_HOST, 
  database: "telegraf", 
  time_precision: 's'

def fix_data( h )
  h.delete("@version")
  h.delete("@timestamp")
  h.delete("EventReceivedTime")
  h.delete("SourceModuleName")
  h.delete("SourceModuleType")
  h.delete("Event-Source")
  h.delete("type")
  h.delete("tags")
  h.delete("host")
  h.delete("port")
  
  h.each do |k,v| 
    if(v.is_a? Numeric)
      h[k]=v.to_s
    end
  end
  # "Timestamp":"09/26/2016 06:15:06.321"
  dt = DateTime.strptime(h.delete("Timestamp"), '%m/%d/%Y %H:%M:%S.%L')
  # puts (dt.to_time-60*60*(TIME_ZONE)).utc
  h.store("timestamp", (dt.to_time-60*60*(TIME_ZONE)).to_i)
end

def save_data( h )
  ts = h.delete("timestamp")
  data = {
    tags: h,
    values: { z: 0 },
    timestamp: ts
  }
  @influxdb.write_point("nps_all", data)
end

server = UDPSocket.new
server.bind(NPS_LISTEN_ADDR, NPS_LISTEN_PORT)
puts "start"
data = []
i = 0
loop do
  text, sender = server.recvfrom(65536)  
  # text, sender = server.recvfrom_nonblock(65536)  
    #=> ["aaa", ["AF_INET", 33302, "localhost.localdomain", "127.0.0.1"]]
  # puts "#{text}:\n  #{sender}"
  # puts JSON.parse(text)
  # data << JSON.parse(text)
  data = JSON.parse(text)
  fix_data(data)
  save_data(data)
end
