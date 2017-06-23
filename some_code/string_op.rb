require 'rubygems'
require 'date'
require 'pp'
s = ''

s.upcase!
puts s
r = "#{s[0,2]}-#{s[2,2]}-#{s[4,2]}-#{s[6,2]}-#{s[8,2]}-#{s[10,2]}"
puts r

def fix_mac(s)
  if(s.is_a? String)
    if(!s.empty?)
      s.upcase!
      return "#{s[0,17]}"
    else
      return s
    end
  else
    return s
  end
end


puts fix_mac('01-cc-5f-23-af-ed:ITFFF')


def fix_class(s)
  ip=''
  id=0
  time=0
  if((s.is_a? String) && !s.empty?)
    arr = s.split
    pp arr
    if(arr.length == 6)
      ip = arr.at(2)
      id = arr.at(5).to_i
      # time = 04/20/2016 20:20:23
      time = DateTime.strptime(arr.at(3)+" "+arr.at(4), '%m/%d/%Y %H:%M:%S').to_time.to_i
    end
  end
  return ip, time, id
end

ip, time, id = fix_class(s)
puts ip, time, id
