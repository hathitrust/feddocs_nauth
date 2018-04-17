require_relative '../lib/nauth'
require 'dotenv'
require 'pp'
Dotenv.load
Mongoid.load!("config/mongoid.yml", :production)
Authority = Nauth::Authority

count = 0
Authority.where(parents:"").no_timeout.each do |auth|
  if auth.parents.include? ''
    puts "fail"
    PP.pp auth.marc
    exit
  end
  count += 1
  auth.save
end
puts "num fixed: #{count}"
