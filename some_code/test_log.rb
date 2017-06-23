require 'lumberjack'

logger = Lumberjack::Logger.new("E:/!Code/Ruby/udp_listener/tmp/logs/application.log", :max_size => 1*1024, :level => :debug)  # Open a new log file with INFO level
logger.info("Begin request")
logger.debug("params")  # Message not written unless the level is set to DEBUG
begin
  raise 'A test exception.'
rescue Exception => exception
  logger.error(exception)
end
logger.info("End request")
