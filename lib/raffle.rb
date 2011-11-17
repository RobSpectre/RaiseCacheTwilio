require 'rubygems'
require 'mongo'

# handles all raffle ticket functions
class Raffle
  
  def initialize(phone)
    @phone = phone
    
    @register_msg = "Thanks for participating in the Raise Cache raffle, %s! 100%% of proceeds go to hackNY. You currently have 1 raffle ticket to spend. Text LIST to see a list of raffle prizes."
    @register_err = "Hi there! You're already registered. Text LIST to see a list of raffle prizes."

    @list_line = "%d %s\n"
    @list_msg = "\nText [number] to apply your raffle ticket for that prize."

    @info_msg = "%d %s:\n%s\n\nCurrent bid is: $%d\n\nText [number] $[amount] to bid."
    @info_err = "Invalid auction item. Text LIST to see a list of auction items."
    
    @apply_msg = "Great! Your raffle ticket has been entered into the drawing for %s."
    @apply_err = "Invalid bid item."

    @db_name = 'rc_raffle'
    @items_coll = 'prizes'
    @bidders_coll = 'hopefuls'

    @db = Mongo::Connection.new.db(@db_name)
  end
  
  # verifies the raffle participant is legit
  def is_valid_bidder
    if @db[@bidders_coll].find_one('phone' => @phone) == nil then
      false
    else
      true
    end
  end
  
  # registers a new raffle participant
  def register (name, ticket_number)
    result = @db[@bidders_coll].find_one('phone' => phone)
    if result == nil then
      @db[@bidders_coll].insert({
        'name' => name,
        'ticket_number' => ticket_number,
        'phone' => phone
      })
      sprintf(@register_msg, name.split(' ')[0])
    else
      @register_err
    end
  end
  
  # lists the available raffle prizes
  def get_list
    return @not_registered_msg unless self.is_valid_bidder
    
    list = ''
    @db[@items_coll].find().each do |item|
      list += sprintf(@list_line, item['number'], item['name'])
    end
    "#{list}#{@list_msg}"
  end
  
  # applies a raffle ticket to the specified prize
  def apply_ticket (prize_number)
    return @not_registered_msg unless self.is_valid_bidder
    
    item = @db[@items_coll].find_one('number' => item_number)
    if item == nil then
      @apply_err
    else
      sprintf(@apply_msg, amount, item['number'], item['name'])
    end
  end
  
end