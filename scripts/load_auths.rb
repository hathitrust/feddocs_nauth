require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!("config/mongoid.yml", :production)
Authority = Nauth::Authority
count = 0
skipped = 0
line_count = 0

ARGV.each do | file |
  open(file).each do | line |
    line_count += 1
    if line.nil?
      puts "wtf"
      next
    end

    begin 
      rec = Authority.new(:marc=>line)
    rescue RuntimeError => e
      if e.message =~ /not a person or persons/
        skipped += 1
        next
      else
        puts line
        raise e
      end
    end

    if !rec.name
      next
    end

    if !rec.valid? 
      puts line
      rec.save!
    end
    rec.save!
=begin
    if !rec.valid? and 
      old_rec = Authority.find_by(name:rec.name)
      old_rec.sameAs ||= rec.sameAs
      if old_rec.alternate_names.count == 0 and 
        rec.alternate_names.count > 0
        old_rec.alternate_names ||= rec.alternate_names
      end
      old_rec.save
    else
      rec.save!
    end
=end
  end
end

puts "count: #{count}"
puts "skipped: #{skipped}"
