require 'pp'
require 'nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!("config/mongoid.yml", :development)
Authority = Nauth::Authority
RSpec.describe Authority, "#new" do

  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/schizo_branch.ndj").read
    @schizo = Authority.new( :marc=>rec )
    @schizo.save!
    rec = open(File.dirname(__FILE__)+"/data/person.ndj").read
    @person = Authority.new( :marc=>rec)
    @person.save!
    @noaa = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/noaa.json").read)
    @noaa.save!
  end

  it "creates three records from 1 authority record" do
    expect(@schizo.name).to eq("National Institute of Mental Health (U.S.). Division of Clinical Research. Schizophrenia Research Branch")
    expect(@schizo.label).to eq("Schizophrenia Research Branch")
    expect(@schizo.parentOrganization).to eq("National Institute of Mental Health (U.S.). Division of Clinical Research")
    expect(@schizo.type).to eq('Organization')
  end

  it "extracts alternate names from 410/510" do
    expect(@noaa.alternate_names).to include("United States. National Oceanic and Atmospheric Administration. Coastal Ocean Program Office")
    expect(@schizo.successors).to include("National Institute of Mental Health (U.S.). Division of Clinical and Treatment Research. Schizophrenia Research Branch")
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

  it "extracts a person authority record" do
    expect(@person.name).to eq('Pāṇḍeya, Gaṅgāprasāda')
    expect(@person.alternate_names).to include('Gaṅgāprasāda Pāṇḍeya')
    expect(@person.sameAs).to eq('https://lccn.loc.gov/n89253171')
    expect(@person.type).to eq('Person')
    expect(@person['type']).to eq('Person')
  end

  it "saves the marc" do
    per = Authority.find_by(name:'Pāṇḍeya, Gaṅgāprasāda')
    expect(per.marc).to be_truthy
  end

  after(:all) do
    Authority.delete_all
  end

end

RSpec.describe Authority, "#new" do
  it "extracts the 'n' subfield in order" do
    rec = open(File.dirname(__FILE__)+"/data/with_110n.json").read
    rec = Authority.new( :marc=>rec )
    expect(rec.name).to eq('United States. Congress (97th, 2nd session : 1982). Senate')
    expect(rec.parentOrganization).to eq('United States. Congress (97th, 2nd session : 1982)')
    p = Authority.where(name:'United States. Congress (97th, 2nd session : 1982)').first
    expect(p.label).to eq('Congress (97th, 2nd session : 1982).')
  end

  it "deals with treaty records" do
    rec = open(File.dirname(__FILE__)+"/data/treaty_record.json").read
    rec = Authority.new( :marc=>rec )
    expect(rec.name).to eq('United States. Treaties, etc. 1858 June 19')
  end     

  it "deals with legislative acts" do
    rec = open(File.dirname(__FILE__)+"/data/fake_corp_name.json").read
    rec = Authority.new( :marc=>rec )
    expect(rec.name).to eq('United States. Protecting Americans from Tax Hikes Act of 2015')
    expect(rec.type).to eq('CreativeWork')
  end


  after(:all) do
    Authority.delete_all
  end
end

RSpec.describe Authority, "#parentOrganization" do
  before(:all) do
    @noaa = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/noaa.json").read)
    @noaa.save!
  end

  xit "uses alternate_names to find a more precise parentOrganizations"  do
    expect(@noaa.parentOrganization).to eq("United States. National Oceanic and Atmospheric Administration")
  end

  after(:all) do 
    Authority.delete_all
  end
end

RSpec.describe Authority, "#relations (4XX/5xx)" do
  before(:all) do
    @uscg = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/uscg.json").read)
    @uscg.save!
    @army = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/army_chemical.json").read)
    @army.save!
  end

  it "predecessors extracts from $w/a and i" do
    expect(@uscg.predecessors).to include("United States. Life-Saving Service")
  end

  it "superiors extracts from $wi where appropriate" do
    expect(@uscg.superiors).to include("United States. Department of the Treasury")
    expect(@uscg.superiors).to include("United States. Department of Transportation")
    expect(@uscg.alternate_names).to include("United States. Department of Homeland Security. Coast Guard")
    expect(@uscg.alternate_names).to_not include("United States. Department of the Treasury")
  end

  it "saves the relations fields" do
    auth = Authority.find_by({name:"United States. Coast Guard"})
    expect(auth.superiors).to include("United States. Department of Transportation")
  end

  it "successors extracts from $w/b and i" do
    expect(@army.successors).to include("United States. Army. Chemical Corps. Medical Division")
  end

  after(:all) do
    Authority.delete_all
  end
end

RSpec.describe Authority, "#search" do
  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/with_410.json").read
    @rec = Authority.new(:marc=>rec)
    @rec.save!
  end

  it "finds by name" do
    name = 'Haut Commissariat à la recherche de la République centrafricaine'
    auth = Authority.search name
    expect(auth.sameAs).to eq('https://lccn.loc.gov/n90645849')
  end

  it "finds by alternate name" do
    #not a great test. some of these characters are 'a' acute 
    alternate_name = 'Central African Republic. Haut Commissariat à la recherche'
    auth = Authority.search alternate_name
    expect(auth.sameAs).to eq('https://lccn.loc.gov/n90645849')
  end

  after(:all) do
    Authority.delete_all
  end
end

RSpec.describe Authority, "#pub_count" do
  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/schizo_branch.ndj").read
    @schizo = Authority.new( :marc=>rec )
    @schizo.count = 3
    @schizo.save!
  end

  it "returns count for terminal orgs" do
    expect(@schizo.pub_count).to eq(3)
  end

  it "collects subordinate pub counts" do
    dcr = Authority.find_by(label:"Division of Clinical Research.")
    dcr.count = 2
    dcr.save!
    nimh = Authority.find_by(name:"National Institute of Mental Health (U.S.)")
    expect(nimh.pub_count).to eq(5)
  end

  it "we can differentiate between calculated pub_count and database pubcount" do
    nimh = Authority.find_by(name:"National Institute of Mental Health (U.S.)")
    expect(nimh['pub_count']).to eq(0)
    expect(nimh.pub_count).to eq(5)
    expect(nimh['pub_count']).to eq(5)
    nimh.save!
    nimhb = Authority.find_by(name:"National Institute of Mental Health (U.S.)")
    expect(nimhb['pub_count']).to eq(5) 
  end

  after(:all) do
    Authority.delete_all
  end

end


