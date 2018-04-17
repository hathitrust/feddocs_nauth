# frozen_string_literal: true

require 'marc'
require 'json'

module Nauth
  @encoding_options = encoding_options = {
    external_encoding: 'UTF-8',
    invalid: :replace,
    undef: :replace,
    replace: ''
  }

  def self.marc_to_hash(infile, encoding_options = nil)
    encoding_options ||= {
      external_encoding: 'UTF-8',
      invalid: :replace,
      undef: :replace,
      replace: ''
    }

    reader = MARC::Reader.new(infile, encoding_options)
    Enumerator.new do |enum|
      reader.each { |record| enum.yield record }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  fin = open(ARGV.shift)
  m = Nauth.marc_to_hash fin
  c = 0
  fout = MARC::Writer.new('fifty_marc_records.mrc')
  m.each do |rec|
    c += 1
    fout.write(rec) if c < 51
    puts rec.to_hash.to_json
  end
end
