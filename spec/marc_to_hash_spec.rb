require 'nauth/marc_to_hash'
require 'pp'

RSpec.describe Nauth, "#marc_to_hash" do
  it "converts an authority file to hash" do 
    recs = Nauth::marc_to_hash(File.dirname(__FILE__)+"/data/fifty_marc_records.mrc")
    r = recs.next
    expect(r['008'].value).to eq("131218n| azannaabn          |a aaa      ")
  end
end
