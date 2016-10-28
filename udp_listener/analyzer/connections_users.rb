require 'rubygems'
require 'json'
require 'influxdb'
require 'date'
require 'pp'
require 'ruby-enum'

class Events
  include Ruby::Enum

  define :START, 0
  define :ALIVE, 1
  define :LAX_FINISH, 2 #нестрогий
  define :FINISH, 3 #strict end (строгий, полученный командой dhcp)
end

INFLUX_HOST = "localhost"
# INFLUX_HOST = '10.8.0.1'
TIME_ZONE = 5
TOLERANCE = 2 #The maximum duration of time that two incoming points can be apart and still be considered to be equal in time.
              #in seconds
              #time >= time - TOLERANCE && time < time + TOLERANCE
COUNT_STORED_ELEMENTS = 100
TIME_RANGE=3*60 #pushed the time range, in seconds

@influxdb = InfluxDB::Client.new host: INFLUX_HOST,
  database: "telegraf",
  time_precision: 's'
@stored_data=[]
@last_pushed_time=0
@write_all=false

def find_nps_request(value)
  res = []
  # puts @nps_data.class
  @nps_data.each do |point|
    if(point['Calling-Station-Id']==value && point['Packet-Type']=='1')
      res << point
    end
  end
  return res
end

def find_nps_accept(class_value, req_time)
  # puts '## find_nps_accept ##'
  # res = []
  @nps_data.each do |point|
    if(point['Class']==class_value &&
      point['Packet-Type']=='2' &&
      DateTime.iso8601(point['time']).to_time >= DateTime.iso8601(req_time).to_time)
      return point
    end
  end
  return {}
  # puts res.length
  # return res
end

def push_data()
  # puts "push data"
  if(!@stored_data.empty? && (@stored_data.length >= COUNT_STORED_ELEMENTS || (Time.now.to_i - @last_pushed_time > TIME_RANGE) || @write_all) )
    puts "[#{Time.now.utc}]: [Push] Write #{@stored_data.length} point(s)"
    @influxdb.write_points(@stored_data)
    @stored_data.clear
    @last_pushed_time=Time.now.to_i
  end
end

def close_session(tagname, tagvalue, new_time_start, store_event=Events::LAX_FINISH)
  puts "[#{Time.now.utc}]: [Close] \"#{tagname}\" = '#{tagvalue}', new_time_start=#{new_time_start} Event=#{store_event}"
  named_parameter_query = "SELECT last(z)
                          FROM connection_test
                          WHERE \"#{tagname}\" = %{tagvalue} AND (Event = '#{Events::FINISH}' OR Event = '#{Events::LAX_FINISH}')"
  last_time_finish=0
  last_time_start=0
  res = @influxdb.query( named_parameter_query, params: {tagvalue: tagvalue} )
  if(!res.empty?)
    if(!res.first['values'].empty?)
      last_time_finish = DateTime.iso8601(res.first['values'].first['time']).to_time.to_i
    end
  end
  res = nil
  named_parameter_query = "SELECT last(z)
                          FROM connection_test
                          WHERE \"#{tagname}\" = %{tagvalue} AND Event = '#{Events::START}'
                          AND time > #{last_time_finish}s AND time < #{new_time_start}s"
  res = @influxdb.query( named_parameter_query, params: {tagvalue: tagvalue} )
  if(!res.empty?)
    puts "[#{Time.now.utc}]: [Close] Was founded open session for \"#{tagname}\" = '#{tagvalue}'."
    if(!res.first['values'].empty?)
      last_time_start = DateTime.iso8601(res.first['values'].first['time']).to_time.to_i
      if(last_time_start!=0)
        named_parameter_query = "SELECT *
                                FROM connection_test
                                WHERE \"#{tagname}\" = %{tagvalue} AND Event = '#{Events::START}'
                                AND time >= #{last_time_start}s AND time < #{last_time_start+1}s"
        res = @influxdb.query( named_parameter_query, params: {tagvalue: tagvalue} )
        if(!res.empty?)
          if(!res.first['values'].empty?)
            last_start_point = res.first['values'].first
            last_start_point['time'] = new_time_start - 1 #теперь это конец
            store_point( store_event, last_start_point, new_time_start - last_time_start )
          end
        end
      end
    end
  else
    puts "[#{Time.now.utc}]: [Close] All sessions was closed for \"#{tagname}\" = '#{tagvalue}'"
  end
end

def find_connection(where_condition)
  named_parameter_query = "SELECT *
                          FROM connection_test
                          WHERE #{where_condition}"
  return @influxdb.query( named_parameter_query )
end

def find_connection_last(where_condition)
  named_parameter_query = "SELECT last(z)
                          FROM connection_test
                          WHERE #{where_condition}"
  last_time=0
  res = @influxdb.query( named_parameter_query )
  if(!res.empty?)
    if(!res.first['values'].empty?)
      last_time = DateTime.iso8601(res.first['values'].first['time']).to_time.to_i
    end
  end
  return last_time
end

def fix_username(n)
  if(n.is_a? String)
    return n.split('\\').join("\\\\")
  else
    return n
  end
end

def store_point(event, point, field=0)
  # puts '## store_point ##'
  case event
  when Events::START
    # puts point
    # point[:UserName]
    ts = point.delete(:time)
    find_query="time >= #{ts-1}s AND time < #{ts+1}s
                AND \"UserName\"='#{fix_username(point[:UserName])}'
                AND Ip='#{point[:Ip]}' AND Event='#{event}'"
    if( !find_connection(find_query).empty? )
      #если такая запись уже есть, зачем что-то писать
      #don't store the point if this point exists
      puts "[#{Time.now.utc}]: [Strore=#{event}] [ts=#{Time.at(ts).utc}] This point already exists"
      return
    end
    close_session("UserName", point[:UserName], ts)
    close_session("Ip", point[:Ip], ts)
    puts "[#{Time.now.utc}]: [Strore=#{event}] [ts=#{Time.at(ts).utc}] #{point}"
    point[:Event]=event
    @stored_data << {
      series: "connection_test",
      tags: point,
      values: { z: field },
      timestamp: ts
    }
    push_data()
  when Events::LAX_FINISH, Events::FINISH
    # puts "finish"
    z_field = point.delete('z')
    ts = point.delete('time')
    puts "[#{Time.now.utc}]: [Strore=#{event}] [ts=#{Time.at(ts).utc}] #{point}"
    point['Event']=event
    @stored_data << {
      series: "connection_test",
      tags: point,
      values: { z: z_field },
      timestamp: ts
    }
    push_data()
  else
    # puts "[#{Time.now.utc}]: [Strore=#{event}] Unknown the event for storing"
  end
end

def dhcp_f_assign(dhcp_point)
  last_time_start = find_connection_last("\"UserMac\"='#{dhcp_point['mac_address']}' AND \"Event\"='#{Events::START}'")
  last_time_finish = find_connection_last("\"UserMac\"='#{dhcp_point['mac_address']}' AND (\"Event\"='#{Events::FINISH}' OR \"Event\"='#{Events::LAX_FINISH}')")
  last_time_start_ip = find_connection_last("\"Ip\"='#{dhcp_point['ip_address']}' AND \"Event\"='#{Events::START}'")
  last_time_finish_ip = find_connection_last("\"Ip\"='#{dhcp_point['ip_address']}' AND (\"Event\"='#{Events::FINISH}' OR \"Event\"='#{Events::LAX_FINISH}')")
  # puts "last_time_start  #{last_time_start}"
  # puts "last_time_finish #{last_time_finish}"
  if(last_time_finish <= last_time_start)
    #session wasn't closed
    puts "[#{Time.now.utc}]: [Assign] Session wasn't closed for mac #{dhcp_point['mac_address']}"
    res = find_connection("time >= #{last_time_start-1}s AND time <= #{last_time_start+1}s AND \"UserMac\"='#{dhcp_point['mac_address']}' AND \"Event\"='#{Events::START}'")
    if(!res.empty?)
      if(!res.first['values'].empty?)
        connection_point = res.first['values'].first
        # puts connection_point
        # puts connection_point.class
        point = {
          time: DateTime.iso8601(dhcp_point['time']).to_time.to_i,
          UserName: connection_point['UserName'],
          HostName: dhcp_point['hostname'],
          NasName: connection_point['NasName'],
          Ip: dhcp_point['ip_address'],
          UserMac: dhcp_point['mac_address']
          }
        if(connection_point['Ip'] != dhcp_point['ip_address'])
          # puts "new ip"
          store_point(Events::START, point)
        else
          # puts "alive"
          store_point(Events::ALIVE, point)
        end
      end
    end
  end
  if(last_time_finish_ip <= last_time_start_ip)
    res = find_connection("time >= #{last_time_start_ip-1}s AND time <= #{last_time_start_ip+1}s AND \"Ip\"='#{dhcp_point['ip_address']}' AND \"Event\"='#{Events::START}'")
    if(!res.empty?)
      if(!res.first['values'].empty?)
        connection_point = res.first['values'].first
        # puts "Connection mac: #{connection_point}"
        if(connection_point['UserMac'] != dhcp_point['mac_address'])
          puts "[#{Time.now.utc}]: [Assign] Session wasn't closed for ip #{dhcp_point['ip_address']}"
          ts = DateTime.iso8601(dhcp_point['time']).to_time.to_i
          close_session("Ip", dhcp_point['ip_address'], ts)
        end
      end
    end
  end
end

def dhcp_f_release(dhcp_point)
  close_session("UserMac", dhcp_point['mac_address'], ts, Events::FINISH)
  close_session("Ip", dhcp_point['ip_address'], ts, Events::FINISH)
end

def dhcp_f_expired(dhcp_point)
  close_session("Ip", dhcp_point['ip_address'], ts, Events::FINISH)
end

def dhcp_f_renew(dhcp_point)
  puts "[#{Time.now.utc}]: [Renew] A renew packet was received"
  # puts '## dhcp_f_renew ##'
  # pp dhcp_point
  nps_r = find_nps_request(dhcp_point['mac_address'])
  connection_point = {}
  if(!nps_r.empty?)
    i=0
    n_accept=0
    nps_r.each do |nps_point|
      nps_a = find_nps_accept(nps_point['Class'], nps_point['time'])
      # puts "#{i}: [NPS] [#{!nps_a.empty?}] #{nps_point}"
      # puts "#{i}:              #{nps_a}"
      if( !nps_a.empty? )
        accept_time = nps_a['time']
          # puts DateTime.iso8601(dhcp_point['time']).to_time
          # puts DateTime.iso8601(nps_point['time']).to_time - TOLERANCE
          # puts DateTime.iso8601(nps_point['accept_time']).to_time + TOLERANCE
          # puts DateTime.iso8601(dhcp_point['time']).to_time.to_i
        if(DateTime.iso8601(dhcp_point['time']).to_time >= DateTime.iso8601(nps_point['time']).to_time - TOLERANCE &&
           DateTime.iso8601(dhcp_point['time']).to_time < DateTime.iso8601(accept_time).to_time + TOLERANCE)
          point = {
            time: DateTime.iso8601(dhcp_point['time']).to_time.to_i,
            UserName: nps_point['SAM-Account-Name'],
            HostName: dhcp_point['hostname'],
            NasName: nps_point['Client-Friendly-Name'],
            Ip: dhcp_point['ip_address'],
            UserMac: dhcp_point['mac_address']
            }
          store_point(Events::START, point)
          n_accept+=1
        end
      end
      i+=1
    end
    # puts "Found #{n_accept} request-accept points"
  else
    dhcp_f_assign(dhcp_point)
  end
end

def read_dhcp(min_time, max_time)
  named_parameter_query = "SELECT id, hostname, ip_address, mac_address, z
                          FROM dhcp_all WHERE time >= %{1} and time < %{2}
                          LIMIT 5"
  # res = []
  @influxdb.query named_parameter_query,
                  params: [min_time.to_i*1000000000, max_time.to_i*1000000000] do |name, tags, points|
    points.each do |pt|
      case pt['id']
      when '11' #renew
        dhcp_f_renew(pt)
      when '16', '17', '18'  #expired and deleted
        dhcp_f_expired(pt)
      when '10' #assign
        dhcp_f_assign(pt)
      when '12' #release
        dhcp_f_release(pt)
      else
        # puts 'Unknow ID'
      end
      # res << pt
    end
  end
  # puts res[0]['id']
end

def read_nps(min_time, max_time)
  named_parameter_query = "SELECT \"Authentication-Type\",
                          \"Calling-Station-Id\",
                          \"Class\",
                          \"Client-Friendly-Name\",
                          \"Packet-Type\",
                          \"SAM-Account-Name\",
                          z
                          FROM nps_all
                          WHERE time >= %{1} AND time < %{2}
                                AND \"Authentication-Type\"='11'"
  res = []
  @influxdb.query named_parameter_query,
                  params: [min_time.to_i*1000000000, max_time.to_i*1000000000] do |name, tags, points|
    points.each do |pt|
      res << pt
    end
  end
  # puts (!res.empty?)? "#{res[0]['Authentication-Type']}" : "empty"
  return res
end

# puts "Write all points? #{@write_all}"
puts "[#{Time.now.utc}]: [Start]"
# @nps_data = read_nps(Time.now - 5*60, Time.now)
@nps_data = read_nps(Time.now - 30, Time.now)
puts "Readed #{@nps_data.length} nps points"
# read_dhcp(Time.now - 5*60, Time.now)
read_dhcp(Time.now - 20, Time.now - 10)

@write_all=true
push_data()
puts "[#{Time.now.utc}]: [End]"


###### TEMP ##########
# read_dhcp(Time.now - 2*10, Time.now-10) # 10 seconds window of 10 seconds later

# close_session("UserName", 'IT-GRP\evkulagin', Time.now.to_i)

# s = 'IT-GRP\evkulagin'
# s = fix_username(s)
# puts s
