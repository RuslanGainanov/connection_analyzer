require 'socket'
require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'
require 'lumberjack'
require 'grok-pure'

INFLUX_HOST = "localhost"
LISTEN_PORT = 514
LISTEN_ADDR = "0.0.0.0"
TIME_ZONE = 5
COUNT_STORED_ELEMENTS = 100
TIME_RANGE=1*60 #pushed the time range, in seconds

@stored_data=[]
@influxdb = InfluxDB::Client.new host: INFLUX_HOST, 
  database: "itgrp_listen", 
  time_precision: 's'
@last_pushed_time=0
@logger = Lumberjack::Logger.new("/var/log/udp_listener/syslog.log", :max_size => 100*1024*1014, :level => :debug)
# @logger = Lumberjack::Logger.new("C:/tmp/syslog.log", :max_size => 100, :level => :debug)
@grok = Grok.new
@grok.add_patterns_from_file("/var/udp_listener/patterns/pure-ruby/base")
# @grok.add_patterns_from_file("C:/Ruby23/lib/ruby/gems/2.3.0/gems/jls-grok-0.11.4/patterns/pure-ruby/base")
@grok.compile("<%{NUMBER}>%{SYSLOGTIMESTAMP:ts} %{IP:ip} %{WORD:level}: %{GREEDYDATA:message}")

def fix_data( h )
  h.delete("@version")
  h.delete("@timestamp")
  h.delete("tags")
  h.delete("host")
  
  match = @grok.match(h["message"])
  if match
    h["message"]=match.captures["message"].join.strip
    h["level"]=match.captures["level"].join
    h["host_ip"]=match.captures["ip"].join
    h["timestamp"]=match.captures["ts"].join
  end
  
  dt = DateTime.strptime("#{Time.now.year} #{h["timestamp"]}", '%Y %b %d %H:%M:%S')
  # puts (dt.to_time-60*60*(TIME_ZONE)).utc
  h.store("timestamp", (dt.to_time-60*60*(TIME_ZONE)).to_i)
end

def push_data()
  if(!@stored_data.empty? && (@stored_data.length >= COUNT_STORED_ELEMENTS || Time.now.to_i - @last_pushed_time > TIME_RANGE))
    # puts "[#{Time.now.utc}]: [Push] Write #{@stored_data.length} point(s)"
    @logger.info("[Push] Write #{@stored_data.length} point(s)")
    @influxdb.write_points(@stored_data)
    @stored_data.clear
    @last_pushed_time=Time.now.to_i
  end
end

def save_data( h )
  ts = h.delete("timestamp")
  @stored_data << {
    series: "syslog_all",
    tags: { level: h["level"],
            host_ip: h["host_ip"] },
    values: { message: h["message"] },
    timestamp: ts
  }
end

server = UDPSocket.new
server.bind(LISTEN_ADDR, LISTEN_PORT)
@logger.info("[Start] Listener has started")
loop do
  text, sender = server.recvfrom(65536)  
  data = JSON.parse(text)
  fix_data(data)
  save_data(data)
  push_data()
end
