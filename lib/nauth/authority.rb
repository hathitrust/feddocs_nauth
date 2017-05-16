require 'mongoid'
require 'marc'
require 'dotenv'
require 'traject'
Dotenv.load!
Mongoid.load!("config/mongoid.yml")

module Nauth
  class Authority 
    include Mongoid::Document
    field :name, type: String
    field :parentOrganization, type: String
    field :subOrganization, type: Array, default: []
    field :sameAs, type: String
    field :type, type: String, default: 'Organization'
    field :label, type: String
    field :alternateName, type: Array, default: []
    field :url, type: String
    field :record
    field :count, type: Integer, default: 0

    validates_uniqueness_of :name
    Dotenv.load

    @@extractor = Traject::Indexer.new
    @@extractor.load_config_file(__dir__+'/../../config/traject_config.rb')
    @@loc_uri = "https://lccn.loc.gov/"

    def initialize *args 
      super
    end

    def record=rec
      rec = JSON.parse(rec)
      marc = MARC::Record.new_from_hash(rec) 
      if !marc.nil?
        extracted = @@extractor.map_record(marc)
        if !extracted['name']
          return nil
        end
        extracted['name'] = extracted['name'][0].gsub(/([^\.])\t/, '\1 ').split("\t")
        self.name = extracted['name'].join(' ').chomp('.')
        self.label = extracted['name'].pop
        self.sameAs = @@loc_uri+extracted['sameAs'][0].gsub(/ /,'')
        if extracted['alternateName']
          extracted['alternateName'].each do |aname|
            self.alternateName << aname
          end
          self.alternateName.uniq!
        end
        if extracted['name'].count > 0
          self.parentOrganization = extracted['name'].join(' ').chomp('.')
          self.add_to_parent extracted['name'] 
        end
      end     
    end

    # recursively add/create parent given a parent name array
    def add_to_parent name
      parent = Authority.where(name:name.join(' ').chomp('.')).limit(1).first
      if parent.nil?
        # create an empty record
        parent = Authority.new
        parent.name = name.join(' ').chomp('.')
        parent.label = name.pop
        parent.subOrganization << self.name
        parent.subOrganization.uniq!
        parent.type = self.type
        if name.count > 0
          parent.parentOrganization = name.join(' ').chomp('.')
          parent.add_to_parent name
        end
      else
        parent.subOrganization << self.name
        parent.subOrganization.uniq!
      end
      parent.save
    end 

    # collect pub counts for this org and any subordinates
    # Don't do this on "United States" !
    def pub_count
      total_pubs = self.count
      self.subOrganization.each do | sub |
        s = Authority.find_by(name:sub)
        total_pubs += s.pub_count #will recursively call pub_count on subs
      end
      total_pubs
    end
  end
end
