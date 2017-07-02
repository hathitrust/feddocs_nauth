require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!("config/mongoid.yml", :production)
Authority = Nauth::Authority

#us_root = Authority.find_by(name:"United States")
#puts "United States pub count before running: #{us_root['pub_count']}"
#puts "United States pub count: #{us_root.pub_count}"
#us_root.save
#get pub counts for non us_root auths
Authority.where(count:{"$gt":0}).no_timeout.each do |a|
  #next if a.name =~ /^United States\./
  #a.pub_count
  a.successors
  a.predecessors
  a.subordinates
  a.employers
  a.superiors
  a.save
end
  
