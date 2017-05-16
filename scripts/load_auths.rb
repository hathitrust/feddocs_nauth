require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!("config/mongoid.yml", :production)
Authority = Nauth::Authority

ARGV.each do | file |
  open(file).each do | line |
    if line.nil?
      puts "wtf"
      next
    end
    rec = Authority.new(:record=>line)
    if !rec.name
      next
    end

    if !rec.valid? and 
      old_rec = Authority.find_by(name:rec.name)
      old_rec.sameAs ||= rec.sameAs
      if old_rec.alternateName.count == 0 and 
        rec.alternateName.count > 0
        old_rec.alternateName ||= rec.alternateName
      end
      old_rec.save
    else
      rec.save!
    end
  end
end
