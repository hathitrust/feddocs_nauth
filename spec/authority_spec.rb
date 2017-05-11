require 'pp'
require 'nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!("config/mongoid.yml")
Authority = Nauth::Authority

RSpec.describe Authority, "#new" do

  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/schizo_branch.ndj").read
    @schizo = Authority.new( :record=>rec )
    #@schizo.record = rec
    @schizo.save
  end

  it "creates three records from 1 authority record" do
    expect(@schizo.name).to eq("National Institute of Mental Health (U.S.). Division of Clinical Research. Schizophrenia Research Branch")
    expect(@schizo.label).to eq("Schizophrenia Research Branch")
    expect(@schizo.parentOrganization).to eq("National Institute of Mental Health (U.S.). Division of Clinical Research")
  end

  it "extracts alternate names from 410/510" do
    expect(@schizo.alternateName).to include("National Institute of Mental Health (U.S.). Division of Clinical and Treatment Research. Schizophrenia Research Branch")
  end

  it "creates the parent records from 1 authority record" do
    dcr = Authority.where(name:'National Institute of Mental Health (U.S.). Division of Clinical Research').limit(1).first
    expect(dcr.subOrganization).to include('National Institute of Mental Health (U.S.). Division of Clinical Research. Schizophrenia Research Branch')
    nimh = Authority.where(name:"National Institute of Mental Health (U.S.)").limit(1).first
    expect(nimh.subOrganization).to include('National Institute of Mental Health (U.S.). Division of Clinical Research')
  end

  it "ensures uniqueness of name" do
    dupe_name = 'National Institute of Mental Health (U.S.). Division of Clinical Research. Schizophrenia Research Branch'
    dupe_rec = Authority.create(name:dupe_name)
    expect(dupe_rec.valid?).to be_falsey
    c = Authority.where(name:'National Institute of Mental Health (U.S.). Division of Clinical Research. Schizophrenia Research Branch').count
    expect(c).to eq(1)
  end

  after(:all) do
    Authority.delete_all
  end

end

RSpec.describe Authority, "#new" do

end

RSpec.describe Authority, "#pub_count" do
  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/schizo_branch.ndj").read
    @schizo = Authority.new( :record=>rec )
    @schizo.count = 3
    @schizo.save
  end

  it "returns count for terminal orgs" do
    expect(@schizo.pub_count).to eq(3)
  end

  it "collects subordinate pub counts" do
    dcr = Authority.find_by(label:"Division of Clinical Research.")
    dcr.count = 2
    dcr.save
    nimh = Authority.find_by(name:"National Institute of Mental Health (U.S.)")
    expect(nimh.pub_count).to eq(5)
  end

  after(:all) do
    Authority.delete_all
  end

end


