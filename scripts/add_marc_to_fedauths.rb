# frozen_string_literal: true

require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!('config/mongoid.yml', :production)
Authority = Nauth::Authority

# adding the actual MARC record to nauth_authorities with pub_count > 0
ARGV.each do |file|
  puts file
  open(file).each do |line|
    if line.nil?
      puts 'wtf'
      next
    end
    rec = Authority.new(marc: line)
    next unless rec.name

    if !rec.valid? &&
       (old_rec = Authority.find_by(name: rec.name))
      old_rec.sameAs ||= rec.sameAs
      if (old_rec.alternateName.count == 0) &&
         (rec.alternateName.count > 0)
        old_rec.alternateName ||= rec.alternateName
      end
      old_rec.marc = rec.marc
      old_rec.save
    else
      rec.save!
    end
  end
end
