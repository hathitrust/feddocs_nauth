require 'marc'
require 'json'

module Nauth

  @encoding_options = encoding_options = { 
    :external_encoding => "UTF-8",
    :invalid => :replace,
    :undef   => :replace,
    :replace => '', 
  }

  def self.marc_to_hash infile, encoding_options=nil
    encoding_options ||= { 
      :external_encoding => "UTF-8",
      :invalid => :replace,
      :undef   => :replace,
      :replace => '', 
    }

    reader = MARC::Reader.new(infile, encoding_options)
    Enumerator.new do |enum|
      for record in reader
        enum.yield record
      end
    end
  end
end

if __FILE__ == $0
  fin = open(ARGV.shift)
  m  = Nauth::marc_to_hash fin
  c = 0
  fout = MARC::Writer.new('fifty_marc_records.mrc')
  m.each do | rec |
    c += 1
    if c < 51
      fout.write(rec)
    end
    puts rec.to_hash.to_json
  end
end
