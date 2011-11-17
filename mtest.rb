require 'rubygems'
require 'mongo'
db = Mongo::Connection.new.db "rc_auction"
#coll = db.users['find_one']
#result = coll('phone' => params['From'])
result = db['users'].find_one('phone' => '8582480841')
if result == nil then
	puts 'nope'
else
	puts 'yep'
end

