require 'socket'
require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'

INFLUX_HOST = "localhost"
LISTEN_PORT = 5241
LISTEN_ADDR = "0.0.0.0"
TIME_ZONE = 5
COUNT_STORED_ELEMENTS = 100
TIME_RANGE=3*60 #pushed the time range, in seconds

@stored_data=[]
@influxdb = InfluxDB::Client.new host: INFLUX_HOST,
  database: "itgrp_listen",
  time_precision: 's'
@last_pushed_time=0

def fix_mac(s)
  if(s.is_a? String)
    if(!s.empty?)
      s.upcase!
      return "#{s[0,2]}-#{s[2,2]}-#{s[4,2]}-#{s[6,2]}-#{s[8,2]}-#{s[10,2]}"
    else
      return s
    end
  else
    return s
  end
end

def fix_class(s)
  ip=''
  id=0
  time=0

  if((s.is_a? String) && !s.empty?)
    arr = s.split
    if(arr.length == 6)
      ip = arr.at(2)
      id = arr.at(5).to_i
      # time = 04/20/2016 20:20:23
      time = DateTime.strptime(arr.at(3)+" "+arr.at(4), '%m/%d/%Y %H:%M:%S').to_time.to_i
    end
  end
  return ip, time, id
end

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

  h["Calling-Station-Id"] = fix_mac(h["Calling-Station-Id"])
  h["Called-Station-Id"] = fix_mac(h["Called-Station-Id"])
  h["Class-Ip"], h["Class-Time"], h["Class-Id"], = fix_class(h["Class"])

  # "Timestamp":"09/26/2016 06:15:06.321"
  dt = DateTime.strptime(h.delete("Timestamp"), '%m/%d/%Y %H:%M:%S.%L')
  # puts (dt.to_time-60*60*(TIME_ZONE)).utc
  h.store("timestamp", (dt.to_time-60*60*(TIME_ZONE)).to_i)
end

def push_data()
  if(!@stored_data.empty? && (@stored_data.length >= COUNT_STORED_ELEMENTS || Time.now.to_i - @last_pushed_time > TIME_RANGE))
    puts "[#{Time.now.utc}]: [Push] Write #{@stored_data.length} point(s)"
    @influxdb.write_points(@stored_data)
    @stored_data.clear
    @last_pushed_time=Time.now.to_i
  end
end

def save_data( h )
  ts = h.delete("timestamp")
# Reason-Code
# Remote-Server-Address
  @stored_data << {
    series: "nps_all",
    tags: {
            # 'Authentication-Type': h["Authentication-Type"],
            # 'Packet-Type': h['Packet-Type'],

            'Called-Station-Id': h['Called-Station-Id'], #client (switch) mac
            'Client-IP-Address': h['Client-IP-Address'], #client (switch) ip
            'Client-Friendly-Name': h['Client-Friendly-Name'], #client (switch) name

            'NAS-IP-Address': h['NAS-IP-Address'], #nas (server) ip
            'NAS-Identifier': h['NAS-Identifier'], #nas (server) name
            'NAS-Port': h['NAS-Port'], #nas (server) port

            'Calling-Station-Id': h['Calling-Station-Id'], #client (host) mac
            'SAM-Account-Name': h['SAM-Account-Name'], #client (host) sam name
            'Fully-Qualifed-User-Name': h['Fully-Qualifed-User-Name'], #client (host) full name
            'NP-Policy-Name': h['NP-Policy-Name'], #client (host) policy
            # 'User-Name': h['User-Name'], #client (host) name

            'Class-Ip': h['Class-Ip']
            # '': h[''],
            # '': h['']
            # '': h[''],
          },
    values: {
              # z: 0,
              z_ClassTime: h['Class-Time'],
              z_ClassId: h['Class-Id'],
              z_AuthenticationType: h["Authentication-Type"].to_i,
              z_PacketType: h['Packet-Type'].to_i
             },
    timestamp: ts
  }
  # @stored_data << {
  #   series: "nps_all",
  #   tags: h,
  #   values: { z: 0 },
  #   timestamp: ts
  # }
end

server = UDPSocket.new
server.bind(LISTEN_ADDR, LISTEN_PORT)

puts "[#{Time.now.utc}]: [Start] Listener has started"
loop do
  text, sender = server.recvfrom(65536)
  # text, sender = server.recvfrom_nonblock(65536)
    #=> ["aaa", ["AF_INET", 33302, "localhost.localdomain", "127.0.0.1"]]
  # puts "#{text}:\n  #{sender}"
  # puts JSON.parse(text)
  # data << JSON.parse(text)
  data = JSON.parse(text)
  if(data['Authentication-Type']=='11')
    fix_data(data)
    save_data(data)
    push_data()
  end
end
