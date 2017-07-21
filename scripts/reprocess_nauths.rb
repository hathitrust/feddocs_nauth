require_relative '../lib/nauth'
require 'dotenv'
require 'pp'

Dotenv.load
Mongoid.load!("config/mongoid.yml", :production)
Authority = Nauth::Authority
count = 0 
parents_added = 0
Authority.where(marc:{"$exists":1}, type:"Organization", parents:[]).no_timeout.each do | auth |
  count += 1
  auth.alternate_names
  if auth.type == "Organization"
    auth.parents
    auth.predecessors
    auth.successors
  end
  auth.start_period
  auth.end_period
  auth.termination_date
  auth.establishment_date
  if auth['parents'].count > 0
    parents_added += 1
  end
  auth.save
  if auth.parents[0] == "" 
    puts "wth?"
    exit
  end
end
puts "number processed: #{count}"
puts "number with a new parent: #{parents_added}"
