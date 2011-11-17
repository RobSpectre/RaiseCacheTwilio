require 'rubygems'
require 'sinatra'
require 'twilio-ruby'
require 'mongo'
require './lib/auction'
require './lib/raffle'
require 'local_settings'

bad_command_msg = "ehh... I don't know what to do with that. Text HELP for instructions."

get '/' do
  "Stop looking at me."
end

#
# AUCTION
#

get %r{/auction/voice/?} do
  headers['Content-Type'] = 'text/xml; charset=utf8'
  xmldoc = Twilio::TwiML::Response.new do |r|
    r.Say 'Welcome to the Raise Cache auction! Too register for the auction, please text your first and last name to 4 8 4, 7 7, cache. Thats 4 8 4, 7 7, C A C H E'
  end
  xmldoc.text
end

get %r{/auction/sms/?} do
  
  phone = params['From'] == nil ? '' : params['From']
  msg = params['Body'] == nil ? '' : params['Body'].strip
  
  auction = Auction.new(phone)
  
  case msg
  
  # register
  when /^[a-z-.]+\s[a-z-.]+$/i
    response = auction.register(msg)
  
  # list auction items
  when /^LIST$/i
    response = auction.get_list(nil)
  
  # list more auction items
  when /^MORE$/i
    response = auction.get_list(true)

  # show auction item info
  when /^\d+$/
    response = auction.get_info(msg)
  
  # bid
  when /^\d+\s\$?\d+$/
    bid = msg.split ' '
    response = auction.bid(bid[0], bid[1].sub('$',''))
  
  # confirm bid
  when /^(YES|NO)$/i
    response = auction.confirm_bid(msg)
  
  # show help
  when /^HELP$/i
    response = auction.get_help
  
  # psheww-psheww-psheww!
  else
    response = bad_command_msg
    
  end
  
  # respond
  headers['Content-Type'] = 'text/xml; charset=utf8'
  xmldoc = Twilio::TwiML::Response.new do |r|
    r.Sms response
  end
  xmldoc.text
end

#
# RAFFLE
#

get %r{/raffle/voice/?} do
  headers['Content-Type'] = 'text/xml; charset=utf8'
  xmldoc = Twilio::TwiML::Response.new do |r|
    r.Say 'Welcome to the Raise Cache raffle! Too register for the raffle, please text your name and ticket number to 3 0 4, 4 6, cache. Thats 3 0 4, 4 6, C A C H E'
  end
  xmldoc.text
end

get %r{/raffle/sms/?} do
  
  phone = params['From'] == nil ? '' : params['From']
  msg = params['Body'] == nil ? '' : params['Body'].strip
  
  raffle = Raffle.new(phone)
  
  case msg
  
  # register
  when /^[a-z-.]+\s[a-z-.]+\s[a-z0-9]+$/i
    info = msg.split ' '
    response = raffle.register("#{info[0]} #{info[1]}", info[2])
  
  # list raffle prizes
  when /^LIST$/i
    response = raffle.get_list
  
  # apply raffle ticket
  when /^\d+$/
    bid = msg.split ' '
    response = raffle.apply_ticket(bid[0], bid[1].sub('$',''))
  
  # show help
  when /^HELP$/i
    response = raffle.get_help
  
  # psheww-psheww-psheww!
  else
    response = bad_command_msg
    
  end
  
  # respond
  headers['Content-Type'] = 'text/xml; charset=utf8'
  xmldoc = Twilio::TwiML::Response.new do |r|
    r.Sms response
  end
  xmldoc.text
end


not_found do
  status 404
  "um... no."
end
