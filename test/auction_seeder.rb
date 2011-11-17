require 'rubygems'
require 'mongo'

db_name = 'rc_auction'
items_coll = 'items'
bidders_coll = 'bidders'
unconfirmed_bids_coll = 'unconfirmed_bids'

db = Mongo::Connection.new.db(db_name)

(1..15).each do |i|
  db[items_coll].insert({
    'number' => i,
    'name' => 'Item #{i}',
    'info' => 'This is the info for auction item #{i}.'
  })
end