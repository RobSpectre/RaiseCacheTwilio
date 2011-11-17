require 'rubygems'
require 'mongo'
require 'twilio-ruby'

#
# handles all auction bidding functions
#
class Auction
  
  def initialize(phone)
    
    # messages
    @help_msg = "* Text [first_name] [last_name] to register.\n* Text LIST for a list of items.\n* Text [item_number] for item info.\n* Text [number] $[amount] to bid."
    
    @exception_msg = "Oh, snap. Something broke. Call 858 248 0841 for tech support."
    
    @register_msg = "Thanks for participating in the Raise Cache auction, %s! 100%% of proceeds go to hackNY. Text LIST to see a list of auction items. Text HELP for help."
    @register_err = "Hi there! You're already registered. Text LIST to see a list of auction items."
    
    @not_registered_msg = "You must register before you can bid. Please register by texting your first and last name."

    @list_line = "%d. %s $%d\n"
    @list_msg = "*Text [number] for info."
    @list_more_msg = "\n*Text MORE for more."

    @info_msg = "%d. %s:\n%s\n*High bid: $%d\n*Text [number] $[amount] to bid."
    @info_err = "Invalid item. Text LIST to see a list of auction items."
    
    @bid_msg = "You are bidding $%d on auction item %d (%s). Text YES to confirm this bid. Text NO to cancel."
    @bid_low_err = "Sorry, your bid of $%d is too low. The high bid for item %d is $%d. Please increase your bid."
    @bid_invalid_err = "Invalid item. Text LIST to see a list of auction items."

    @confirm_bid_msg = "Thank you! Your bid of $%d for auction item %d (%s) is confirmed. We will text you if you get outbid or if you are the winner."
    @confirm_bid_cancel_msg = "Okay. We've cancelled your bid of $%d for auction item %d. Text LIST to see other auction items."
    @confirm_bid_outbid_msg = "You've been outbid! The high bid for item %d is now $%d.\n* Text YES to automatically increase your bid to $%d.\n* Text [number] $[amount] to bid a different amount."
    @confirm_bid_exist_err = "You don't have any pending bids.\n* Text [number] $[amount] to bid."
    # end messages
    
    # max number of items to send when list is requested
    @list_size_limit = 4
    
    @phone = phone
    
    @db_name = 'rc_auction'
    @items_coll = 'items'
    @bidders_coll = 'bidders'
    @unconfirmed_bids_coll = 'unconfirmed_bids'

    @db = Mongo::Connection.new.db(@db_name)
    #TODO verify db connection
  end
  
  #
  # helper: verifies the bidder is registered
  #
  def is_valid_bidder
    if @db[@bidders_coll].find_one('phone' => @phone) == nil then
      false
    else
      true
    end
  end
  
  #
  # helper: finds the high bid in the given collection of bids
  #
  def get_high_bid (bids)
    if !bids || bids.size == 0 then
      return 0
    else
      bids.sort_by! { |b| b['amount'].to_i }
      return bids.last['amount'].to_i
    end
  end
  
  #
  # registers a new bidder
  #
  def register (name)
    if self.is_valid_bidder == false then
      @db[@bidders_coll].insert({
        'name' => name,
        'phone' => @phone
      })
      sprintf(@register_msg, name.split(' ')[0])
    else
      @register_err
    end
  end
  
  #
  # lists n available auction items, where n = @list_size_limit
  # if do_more is true, it continues from last, otherwise it starts at the beginning
  #
  def get_list(do_more)
    return @not_registered_msg unless self.is_valid_bidder
    
    bidder = @db[@bidders_coll].find_one({ 'phone' => @phone })
    
    if do_more == true
      last_item = bidder['last_item'] == nil ? 0 : bidder['last_item']
    else
      last_item = 0
    end
    
    more_msg = ''
    list = ''
    i = 0
    @db[@items_coll].find.sort('number').each do |item|
      i = i+1
      puts "i: #{i}, last: #{last_item}"
      if i > last_item then
        # add item to list
        list += sprintf(@list_line, item['number'], item['name'], self.get_high_bid(item['bids']))
      end
      
      if i >= last_item + @list_size_limit then
        # update the bidder's position in the list
        bidder['last_item'] = i
        @db[@bidders_coll].save(bidder)
        
        more_msg = @list_more_msg
        break
      end
    end
    
    "#{list}#{@list_msg}#{more_msg}"
  end
  
  #
  # returns info on the given auction item
  #
  def get_info (item_number)
    return @not_registered_msg unless self.is_valid_bidder
    
    item_number = item_number.to_i
    
    item = @db[@items_coll].find_one('number' => item_number)
    if item == nil then
      @info_err
    else
      sprintf(@info_msg, item['number'], item['name'], item['info'], self.get_high_bid(item['bids']))
    end
  end
  
  #
  # places an UNCONFIRMED bid
  #
  def bid (item_number, amount)
    return @not_registered_msg unless self.is_valid_bidder
    
    amount = amount.to_i # quietly convert decimals to integers
    item_number = item_number.to_i
    
    item = @db[@items_coll].find_one('number' => item_number)
    
    # ensure valid auction item
    return @bid_invalid_err if item == nil

    # ensure valid bid amount
    high = self.get_high_bid(item['bids'])
    return sprintf(@bid_low_err, amount, item['number'], high) if amount <= high
    
    # remove any previously unconfirmed bids
    @db[@unconfirmed_bids_coll].remove('bidder_phone' => @phone)
    
    # insert new unconfirmed bid
    @db[@unconfirmed_bids_coll].insert({
      'bidder_phone' => @phone,
      'item_number' => item_number,
      'amount' => amount
    })
    
    sprintf(@bid_msg, amount, item['number'], item['name'])
  end
  
  #
  # confirms the previously placed bid
  #
  def confirm_bid (confirm)
    return @not_registered_msg unless self.is_valid_bidder
    
    bid = @db[@unconfirmed_bids_coll].find_one('bidder_phone' => @phone)
    
    # ensure a bid is pending
    return @confirm_bid_exist_err if bid == nil
    
    # update the bid amount if this follows an outbid situation
    bid['amount'] = bid['new_amount'] if bid['is_outbid'] == true
      
    # cancel bid, if requested
    if confirm.upcase != 'YES' then
      @db[@unconfirmed_bids_coll].remove('bidder_phone' => @phone)
      return sprintf(@confirm_bid_cancel_msg, bid['amount'], bid['item_number'])
    end
    
    item = @db[@items_coll].find_one('number' => bid['item_number'])
    
    # this should not happen
    return @exception_msg if item == nil
    
    # ensure valid bid amount
    high = self.get_high_bid(item['bids'])
    if bid['amount'].to_i <= high then
      bid['is_outbid'] = true
      bid['new_amount'] = high + 10
      @db[@unconfirmed_bids_coll].save bid
      return sprintf(@confirm_bid_outbid_msg, item['number'], high, bid['new_amount'])
    end
    
    # do it
    bids = item['bids']
    new_bid = {
      'ts' => Time.now.to_s,
      'bidder_phone' => bid['bidder_phone'],
      'amount' => bid['amount']
    }
    @db[@items_coll].update(
      { 'number' => bid['item_number'], 'bids' => { '$size' => bids ? bids.size : 0 } },
      { '$push' => { 'bids' => new_bid } }
    )
    
    # remove unconfirmed bid record
    @db[@unconfirmed_bids_coll].remove('bidder_phone' => @phone)

    # Notify last 5 bidders that they are outbid
    self.outbid_notify(item, new_bid['bidder_phone'], new_bid['bidder_phone'])
    
    sprintf(@confirm_bid_msg, bid['amount'], item['number'], item['name'])
  end

  # Here marks /rob's first pass at Ruby.  God help ye.
  def outbid_notify (item, amount, bidder)
    @client = Twilio::REST::Client.new $account_sid, $auth_token
    bids = item['bids'].sort_by{|a, b| a['amount'] <=> b['amount']}
    (0..4).each do |i|
        if bids[i]['bidder_phone'] != bidder then
            @client.account.sms.messages.create(
                :from => $auction_number,
                :to => bids[i]['bidder_phone'],
                :body => "You were outbid for #{item['name']}!  Bid is now #{amount}."
            )       
        end
    end
  end
  
  #
  # returns the help msg
  #
  def get_help
    @help_msg
  end
  
end
