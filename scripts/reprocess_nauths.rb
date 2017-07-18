require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!("config/mongoid.yml", :production)
Authority = Nauth::Authority

Authority.where(marc:{"$exists":1}).no_timeout.each do | auth |
  #auth.marc = auth.marc
  auth.relationships
  auth.alternate_names
  auth.termination_date
  auth.establishment_date
  auth.save
end
