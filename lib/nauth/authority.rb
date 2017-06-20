require 'mongoid'
require 'marc'
require 'dotenv'
require 'traject'

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
    field :count, type: Integer, default: 0 # for just this Auth
    field :pub_count, type: Integer, default: 0 # for this Auth and subordinates
    field :marc

    validates_uniqueness_of :name

    @@extractor = Traject::Indexer.new
    @@extractor.load_config_file(__dir__+'/../../config/traject_config.rb')
    @@loc_uri = "https://lccn.loc.gov/"

    def initialize *args 
      super
    end

    def marc=rec
      if rec.respond_to?(:keys)
        self['marc'] = rec
      else
        self['marc'] = JSON.parse(rec)
      end
      if !self.marc.nil?
        self.type 
        if self.extracted['name']
          self.name = self.extracted['name'].join(' ').chomp('.')
          self.label = self.extracted['name'].pop
          self.sameAs = @@loc_uri+self.extracted['sameAs'][0].gsub(/ /,'')
          if self.extracted['alternateName']
            self.extracted['alternateName'].each do |aname|
              self.alternateName << aname.chomp('.')
            end
            self.alternateName.uniq!
          end
        elsif self.extracted['corp_name']
          self.extracted['corp_name'] = self.extracted['corp_name'][0].gsub(/([^\.])\t/, '\1 ').split("\t")
          self.name = self.extracted['corp_name'].join(' ').chomp('.')
          self.label = self.extracted['corp_name'].pop
          self.sameAs = @@loc_uri+self.extracted['sameAs'][0].gsub(/ /,'')
          if self.extracted['corp_alternateName']
            self.extracted['corp_alternateName'].each do |aname|
              self.alternateName << aname
            end
            self.alternateName.uniq!
          end
       
          self.parentOrganization          
        else
          return nil
        end
      end     
    end

    def extracted
      @extracted ||= @@extractor.map_record(self.marc_record)
    end

    def marc_record
      @marc_record ||= MARC::Record.new_from_hash(self.marc)
    end

    def parentOrganization
      if self.extracted['corp_name'].count > 0
        @parentOrganization ||= self.extracted['corp_name'].join(' ').chomp('.')
        self.add_to_parent self.extracted['corp_name']
      end
      @parentOrganization
    end

    def type
      if @type
        @type
      elsif self.extracted['corp_name']
        @type = 'Organization'
      elsif self.extracted['name']
        @type = 'Person'
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
        parent.type = 'Organization' 
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
      self['pub_count'] = self.count
      self.subOrganization.each do | sub |
        s = Authority.find_by(name:sub)
        self['pub_count'] += s.pub_count #will recursively call pub_count on subs
        s.save
      end
      self['pub_count']
    end

    # search for a given name
    def self.search name
      # prefer names
      auth = Authority.find_by(name:name.chomp('.')) rescue nil
      if auth.nil?
        auth = Authority.where(alternateName:name.chomp('.')).limit(1).first
      end
      auth
    end
  end
end
