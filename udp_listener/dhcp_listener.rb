require 'socket'
require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'

INFLUX_HOST = "localhost"
LISTEN_PORT = 5242
LISTEN_ADDR = "0.0.0.0"
TIME_ZONE = 5
COUNT_STORED_ELEMENTS = 100
TIME_RANGE=3*60 #pushed the time range, in seconds

@stored_data=[]
@influxdb = InfluxDB::Client.new host: INFLUX_HOST, 
  database: "telegraf", 
  time_precision: 's'
@last_pushed_time=0

def fix_data( h )
  h.delete("@version")
  h.delete("@timestamp")
  h.delete("EventReceivedTime")
  h.delete("SourceModuleName")
  h.delete("SourceModuleType")
  h.delete("type")
  h.delete("tags")
  
  h.each do |k,v| 
    if(v.is_a? Numeric)
      h[k]=v.to_s
    end
  end
  
  dt = DateTime.strptime(h.delete("date")+' '+h.delete("time"), '%m/%d/%y %H:%M:%S')
  # puts (dt.to_time-60*60*(TIME_ZONE)).utc
  h.store("timestamp", (dt.to_time-60*60*(TIME_ZONE)).to_i)
end

def push_data()
  if(@stored_data.length >= COUNT_STORED_ELEMENTS || (Time.now.to_i - @last_pushed_time > TIME_RANGE))
    @influxdb.write_points(@stored_data)
    @stored_data.clear
    @last_pushed_time=Time.now.to_i
  end
end

def save_data( h )
  ts = h.delete("timestamp")
  @stored_data << {
    series: "dhcp_real",
    tags: { id: h["id"], 
            description: h["description"],  
            ip_address: h["ip_address"],  
            hostname: h["hostname"],  
            mac_address: h["mac_address"] },
    values: { z: 0 },
    timestamp: ts
  }
  # puts JSON.pretty_generate(h)
  @stored_data << {
    series: "dhcp_all",
    tags: h,
    values: { z: 0 },
    timestamp: ts
  }
end

server = UDPSocket.new
server.bind(LISTEN_ADDR, LISTEN_PORT)
puts "start"
loop do
  text, sender = server.recvfrom(65536)  
  # text, sender = server.recvfrom_nonblock(65536)  
    #=> ["aaa", ["AF_INET", 33302, "localhost.localdomain", "127.0.0.1"]]
  # puts "#{text}:\n  #{sender}"
  # puts JSON.parse(text)
  data = JSON.parse(text)
  fix_data(data)
  save_data(data)
end
