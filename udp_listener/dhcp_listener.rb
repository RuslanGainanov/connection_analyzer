require 'socket'
require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'

INFLUX_HOST = "localhost"
DHCP_LISTEN_PORT = 5242
DHCP_LISTEN_ADDR = "0.0.0.0"

@influxdb = InfluxDB::Client.new host: INFLUX_HOST, 
  database: "telegraf", 
  time_precision: 's'

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
  # puts (dt.to_time-60*60*2).utc
  h.store("timestamp", (dt.to_time-60*60*2).to_i)
end

def save_data( h )
  data = []
  ts = h.delete("timestamp")
  data << {
    series: "dhcp_real",
    tags: { id: h["id"], 
            description: h["description"],  
            ip_address: h["ip_address"],  
            hostname: h["hostname"],  
            mac_address: h["mac_address"] },
    values: { f: 0 },
    timestamp: ts
  }
  # puts JSON.pretty_generate(h)
  data << {
    series: "dhcp_all",
    tags: h,
    values: { f: 0 },
    timestamp: ts
  }
  @influxdb.write_points(data)
end

server = UDPSocket.new
server.bind(DHCP_LISTEN_ADDR, DHCP_LISTEN_PORT)
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
