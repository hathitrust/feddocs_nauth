# frozen_string_literal: true

require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!('config/mongoid.yml', :production)
Mongo::Logger.logger.level = ::Logger::FATAL
Authority = Nauth::Authority

same_as = ARGV.shift
Authority.where(sameAs: same_as).each do |a|
  PP.pp a.marc
  PP.pp a.parents
end
