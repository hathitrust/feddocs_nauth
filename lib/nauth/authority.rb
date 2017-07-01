require 'mongoid'
require 'marc'
require 'dotenv'
require 'traject'

module Nauth
  class Authority 
    include Mongoid::Document
    field :name, type: String
    field :parentOrganization, type: String
    field :superiors, type: Array, default: []
    field :subordinates, type: Array, default: []
    field :predecessors, type: Array, default: []
    field :successors, type: Array, default: []
    field :alternate_names, type: Array, default: []
    field :subOrganization, type: Array, default: []
    field :sameAs, type: String
    field :establishment_date, type: Array
    field :termination_date, type: Array
    field :start_period, type: Array
    field :end_period, type: Array
    field :type, type: String, default: 'Organization'
    field :label, type: String
    field :length, type: Integer, default: 0
    field :alternate_length, type: Integer, default: 0
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
        elsif self.extracted['corp_name']
          self.extracted['corp_name'] = self.extracted['corp_name'][0].gsub(/([^\.])\t/, '\1 ').split("\t")
          self.name = self.extracted['corp_name'].join(' ').chomp('.')
          self.label = self.extracted['corp_name'].pop
          self.sameAs = @@loc_uri+self.extracted['sameAs'][0].gsub(/ /,'')
          self.length = self.extracted['corp_name'].length
          self.parentOrganization          
        else
          return nil
        end
        self.alternate_names
        self.subordinates
        self.superiors
        self.successors
        self.predecessors
        self.employers
        self.start_period
        self.end_period
        self.establishment_date
        self.termination_date

      end     
    end

    def extracted
      @extracted ||= @@extractor.map_record(self.marc_record)
    end

    def marc_record
      @marc_record ||= MARC::Record.new_from_hash(self.marc)
    end

    # computed from the 110 itself
    def parentOrganization
      if self.extracted['corp_name'].count > 0
        self['parentOrganization'] ||= self.extracted['corp_name'].join(' ').chomp('.')
        self.add_to_parent self.extracted['corp_name']
      end
      self['parentOrganization'] 
    end

    def subOrganization
      self['subOrganization'] = Authority.where(parentOrganization:self.name).pluck(:name)
      self['subOrganization'] += self.subordinates
      self['subOrganization'].uniq!
      self['subOrganization']
    end

    def type
      if self.extracted['title']
        self['type'] = 'CreativeWork'
      elsif self.extracted['corp_name']
        self['type'] = 'Organization'
      elsif self.extracted['name']
        self['type'] = 'Person'
      end
    end 

    def get_field 
      if self.extracted[__callee__.to_s]
        self[__callee__] = self.extracted[__callee__.to_s]
      else
        nil   
      end
    end
    alias_method :start_period, :get_field
    alias_method :end_period, :get_field
    alias_method :establishment_date, :get_field
    alias_method :termination_date, :get_field

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
      self.predecessors.each do |pred|
        p = Authority.find_by(name:pred)
        self['pub_count'] += s.pub_count
      end
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
        auth = Authority.where(alternate_names:name.chomp('.')).limit(1).first
      end
      auth
    end

    # handles 4xx and 5xx
    def tracings
      if self[__callee__] == [] and @tracings.nil? and !self.marc.nil?
        @tracings = {superiors:[],
                     subordinates:[],
                     successors:[],
                     predecessors:[],
                     employers:[],
                     alternate_names:[]}
        self.marc_record.each_by_tag(['400','410','500','510']) do | f |
          codes = ['a','b','c','n','t','d']
          pieces = f.find_all {|sub| codes.include? sub.code}.collect{|sub|sub.value}
          this_record = pieces.join(' ')
          case
          when f['i'] =~ /h..rarc.*al superior/i , f['w'] =~ /^t/
            @tracings[:superiors] << this_record.chomp('.')
          when f['i'] =~ /h..rarc.+al subordinate/u
            @tracings[:subordinates] << this_record.chomp('.')
          when f['i'] =~ /suc*es*or/i , f['i'] =~ /product of merger/i ,
            f['i'] =~ /product of split/i , f['i'] =~ /succeeded by/i ,
            f['w'] =~ /^b/
            @tracings[:successors] << this_record.chomp('.')
          when f['i'] =~ /predecessor/i , f['i'] =~ /preceded by/i ,
            f['i'] =~ /mergee/i , f['i'] =~ /component of merger/i , 
            f['i'] =~ /absorbed corporate body/i , f['w'] =~ /^a/
            @tracings[:predecessors] << this_record.chomp('.')
          when f['i'] =~ /employer/i
            @tracings[:employers] << this_record.chomp('.')
          else
            @tracings[:alternate_names] << this_record.chomp('.')
            if self.alternate_length < pieces.count
              self.alternate_length = pieces.count
            end
          end
        end
      end
      if !@tracings.nil?
        self[__callee__] = @tracings[__callee__].uniq
      end
      self[__callee__]
    end
    alias_method :predecessors, :tracings
    alias_method :successors, :tracings
    alias_method :subordinates, :tracings
    alias_method :superiors, :tracings
    alias_method :alternate_names, :tracings
    alias_method :employers, :tracings
  end
end
