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
    @nih = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/nih.json").read)
    @nih.save
  end

  it "throws an error for a subject heading" do
    f = open(File.dirname(__FILE__)+"/data/subject_heading.json").read
    a = Authority.new
    expect{a.marc = f}.to raise_error(RuntimeError)
    f = open(File.dirname(__FILE__)+"/data/sh_rec.json").read
    a = Authority.new
    expect{a.marc = f}.to raise_error(RuntimeError)
  end

  it "extracts alternate names from 410/510" do
    expect(@noaa.alternate_names).to include("United States. National Oceanic and Atmospheric Administration. Coastal Ocean Program Office")
    expect(@schizo.successors).to include("National Institute of Mental Health (U.S.). Division of Clinical and Treatment Research. Schizophrenia Research Branch")
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

  it "extracts the 010 as a sameAs url" do
    expect(@nih.sameAs).to eq('https://lccn.loc.gov/n78085445')
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
  end

  it "deals with treaty records" do
    rec = open(File.dirname(__FILE__)+"/data/treaty_record.json").read
    expect{ Authority.new( :marc=>rec ) }.to raise_error(RuntimeError, "title heading, not a person or persons")
    #expect(rec.name).to eq('United States. Treaties, etc. 1858 June 19')
  end     

  it "deals with legislative acts" do
    rec = open(File.dirname(__FILE__)+"/data/fake_corp_name.json").read
    expect{ Authority.new( :marc=>rec ) }.to raise_error(RuntimeError, "title heading, not a person or persons")
    #expect(rec.name).to eq('United States. Protecting Americans from Tax Hikes Act of 2015')
    #expect(rec.type).to eq('CreativeWork')
  end

  after(:all) do
    Authority.delete_all
  end
end

RSpec.describe Authority, "#relationships (4XX/5xx)" do
  before(:all) do
    # uscg has explicit 510s and 410s
    @uscg = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/uscg.json").read)
    @uscg.save!
    @army = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/army_chemical.json").read)
    @army.save!
    @uscg_ou = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/uscg_ou.json").read)
    @uscg_ou.save!
    #airborne only has a 410. no 510s
    @airborne = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/airborne.json").read)
    @airborne.save!
    @aidecuad = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/aid_ecuador.json").read)
    @aidecuad.save!
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

  it "calculates parents from 410#1s" do
    expect(@uscg.label).to eq("Coast Guard")
    expect(@uscg.parents_calculated).to include("United States. Department of the Treasury")
    expect(@uscg.parents_calculated).to_not include("USCG")
    expect(@airborne.parents_calculated).to include("United States. Coast Guard. Oceanographic Unit")
  end

  it "calculates parents from 410#1s when United States." do
    expect(@aidecuad.parents_calculated).to include("United States. Agency for International Development")
  end

  it "combines explicit and implicitly calculated parents into one" do
    expect(@uscg.parents.count).to eq(5)
    expect(@uscg.parents).to include("United States. Department of the Treasury")
    expect(@airborne.parents).to eq(@airborne.parents_calculated | @airborne.superiors)
  end

  it "collects current and former parents" do
    expect(@army.parents).to include("United States. Army. Chemical Warfare Service")
    usaiir = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/usaiir.json").read)
    expect(usaiir.parents_calculated).to eq([])
    expect(usaiir.parents).to include("United States. Army")
  end

  it "collects children from others calling it a parent" do
    expect(@uscg_ou.children).to include("United States. Coast Guard. Airborne Radiation Thermometer Program")
    expect(@uscg_ou.parents).to include("United States. Coast Guard")
    expect(@uscg.children).to include("United States. Coast Guard. Oceanographic Unit")
    expect(@uscg.children).to_not include("United States. Coast Guard. Airborne Radiation Thermometer Program")
  end

  it "saves the relations fields" do
    auth = Authority.find_by({name:"United States. Coast Guard"})
    expect(auth.superiors).to include("United States. Department of Transportation")
  end

  it "uses the 110 if no 410s or 510s" do
    cyf = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/cyf.json").read)
    cyf.parents
    expect(cyf.parents).to include("United States. Administration for Children, Youth, and Families")
  end

  it "successors extracts from $w/b and i" do
    expect(@army.successors).to include("United States. Army. Chemical Corps. Medical Division")
  end

  it "handles a complicated record's relationships" do
    hew = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/dept_hew.json").read)
    expect(hew.name).to eq('United States. Department of Health, Education, and Welfare')
    expect(hew.label).to eq('Department of Health, Education, and Welfare')
    expect(hew.alternate_names).to include('D.H.E.W')
    expect(hew.alternate_names).to include('DHEW')
    expect(hew.alternate_names).to include('United States. Department of Health')
    expect(hew.predecessors).to include('United States. Federal Security Agency')
    expect(hew.successors).to include('United States. Department of Health and Human Services')
    expect(hew.subordinates).to include('United States. Public Health Service')
    expect(hew.parents).to include('United States')
    jpl = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/jpl.json").read)
    expect(jpl.name).to eq('Jet Propulsion Laboratory (U.S.)')
    expect(jpl.parents).to include('United States. National Aeronautics and Space Administration')

  end

  it "doesn't create blank fields" do
    sldn = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/sldn.json").read)
    expect(sldn.parentOrganization).to be_nil
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

    @nep = Authority.new(:marc=>open(File.dirname(__FILE__)+"/data/nepal.json").read)
    @nep.save!
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

  it "finds by predecessor and successor" do
    #Nepal. Department of Publicity and Broadcasting"
    puts @nep.predecessors
    auth = Authority.search @nep.predecessors[0]
    expect(auth.sameAs).to eq('https://lccn.loc.gov/n50005233')
    puts @nep.successors
    #Nepal. Ministry of Publicity and Broadcasting
    auth = Authority.search @nep.successors[0]
    expect(auth.sameAs).to eq('https://lccn.loc.gov/n50005233')
  end

  after(:all) do
    Authority.delete_all
  end
end

RSpec.describe Authority, "#start_period" do
  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/aba.json").read
    @aba = Authority.new( :marc=>rec )
    @aba.save!
  end

  after(:all) do
    @aba.delete
  end
    
  it "extracts the start of this organization" do
    expect(@aba.start_period).to eq(['1878'])
    expect(@aba.establishment_date).to eq(['est'])
  end

  it "extracts the end of this organization" do
    expect(@aba.end_period).to eq(['never'])
    expect(@aba.termination_date).to eq(['end'])
  end

end

RSpec.describe Authority, "#pub_count" do
  before(:all) do
    rec = open(File.dirname(__FILE__)+"/data/nimh.json").read
    @nimh = Authority.new( :marc=>rec )
    @nimh.count = 1
    @nimh.save!
    rec = open(File.dirname(__FILE__)+"/data/nimh_dcr.json").read
    @nimh_dcr = Authority.new( :marc=>rec )
    @nimh_dcr.count = 2
    @nimh_dcr.save!
    rec = open(File.dirname(__FILE__)+"/data/schizo_branch.ndj").read
    @nimh_dcr_s = Authority.new( :marc=>rec )
    @nimh_dcr_s.count = 3
    @nimh_dcr_s.save!
  end

  it "returns count for terminal orgs" do
    expect(@nimh_dcr_s.pub_count).to eq(3)
  end

  it "collects subordinate pub counts" do
    expect(@nimh.pub_count).to eq(6)
    expect(@nimh_dcr.pub_count).to eq(5)
  end

  it "we can differentiate between calculated pub_count and database pubcount" do
    nimh = Authority.find_by(name:"National Institute of Mental Health (U.S.)")
    expect(nimh['pub_count']).to eq(0)
    expect(nimh.pub_count).to eq(6)
    expect(nimh['pub_count']).to eq(6)
    nimh.save!
    nimhb = Authority.find_by(name:"National Institute of Mental Health (U.S.)")
    expect(nimhb['pub_count']).to eq(6) 
  end

  after(:all) do
    Authority.delete_all
  end

end


