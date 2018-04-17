# frozen_string_literal: true

require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!('config/mongoid.yml', :production)
Authority = Nauth::Authority
count = 0
skipped = 0
line_count = 0

new_us_rec = open(ARGV.shift).read
new_us_rec.chomp!
rec = Authority.where(label: 'United States.').first
puts "num of alternates: #{rec.alternate_names.count}"
rec.marc = new_us_rec
rec.save
puts "num of alternates: #{rec.alternate_names.count}"
