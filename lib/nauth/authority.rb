# frozen_string_literal: true

require 'mongoid'
require 'marc'
require 'dotenv'
require 'traject'

module Nauth
  class Authority
    include Mongoid::Document
    store_in client: "nauth"
    include Mongoid::Attributes::Dynamic
    field :name, type: String
    field :parents, type: Array, default: []
    field :parentOrganization, type: String # computed from 110
    field :superiors, type: Array, default: [] # from tracings only
    field :subordinates, type: Array, default: [] # from tracing labels
    field :predecessors, type: Array, default: []
    field :successors, type: Array, default: []
    field :alternate_names, type: Array, default: []
    field :sameAs, type: String
    field :establishment_date, type: Array # don't actually exist
    field :termination_date, type: Array # don't actually exist
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
    validates_uniqueness_of :sameAs

    @@extractor = Traject::Indexer.new
    @@extractor.load_config_file(__dir__ + '/../../config/traject_config.rb')
    @@loc_uri = 'https://lccn.loc.gov/'

    def initialize(*args)
      super
    end

    def marc=(rec)
      self['marc'] = if rec.respond_to?(:keys)
                       rec
                     else
                       JSON.parse(rec)
                     end
      unless marc.nil?
        type
        if extracted['name']
          self.name = extracted['name'].join(' ').chomp('.')
          self.label = extracted['name'].pop
          self.sameAs = @@loc_uri + extracted['sameAs'][0].delete(' ')
        elsif extracted['corp_name']
          self.name = extracted['corp_name'].join(' ').chomp('.')
          self.label = extracted['corp_name'].last
          self.sameAs = @@loc_uri + extracted['sameAs'][0].delete(' ')
          self.length = extracted['corp_name'].length
          # self.parentOrganization
        else
          return nil
        end
        relationships
        #         #self.subordinates
        #         self.superiors
        #         self.successors
        #         self.predecessors
        #         self.employers
        alternate_names
        start_period
        end_period
        establishment_date
        termination_date

      end
    end

    def relationships
      if type == 'Organization'
        parents
        children
      end
      predecessors
      successors
    end

    def parents
      self['parents'] = superiors | employers | parents_calculated
      # fall back to the 110
      if self['parents'].count == 0
        po = parentOrganization
        self['parents'] = [po] if po
      end
      self['parents']
    end

    def children
      self['children'] = Authority.where(parents: name).pluck(:name)
      self['children'] = self['children'] | subordinates
    end

    def extracted
      unless @extracted
        @extracted = @@extractor.map_record(marc_record)
        # we used tab separators in the traject config, but very
        # occasionally there is a tab in the string. Replace tabs in the
        # string with ' ' if they do not follow a '.'
        if @extracted['corp_name']
          @extracted['corp_name'] = @extracted['corp_name'][0].gsub(/([^\.])\t/, '\1 ').split("\t")
        end
      end
      @extracted
    end

    def marc_record
      @marc_record ||= MARC::Record.new_from_hash(marc)
    end

    # computed from the 110 itself
    def parentOrganization
      if extracted['corp_name'].count > 1
        self['parentOrganization'] ||= extracted['corp_name'][0, extracted['corp_name'].length - 1].join(' ').chomp('.')
      end
      self['parentOrganization']
    end

    # Take parents from the 410/510s
    # There is often more detailed heirarchical information in the tracing
    # fields.
    # field should be array of subfields
    def parent_from_tracings(field)
      # kill extraneous junk then match
      if (field.last == label.sub(/ \(U\.S\.\)$/, '')) && (field.count > 1)
        field[0, field.length - 1].join(' ').chomp('.')
      elsif (field.first == 'United States.') && (field.count > 2)
        lindex = (field.index(label) ||
                  field.index(label + '.') ||
                  (field.length - 1))
        field[0, lindex].join(' ').chomp('.')
      end
    end

    def subOrganization
      self['subOrganization'] = Authority.where(
        parentOrganization: name
      ).pluck(:name)
      self['subOrganization'] += subordinates
      self['subOrganization'].uniq!
      self['subOrganization']
    end

    def type
      raise 'subject heading, not a person or persons' if extracted['subject_heading'] ||
                                                          extracted['sameAs'][0] =~ /^s/
      raise 'title heading, not a person or persons' if extracted['title']
      if extracted['corp_name']
        self['type'] = 'Organization'
      elsif extracted['name']
        self['type'] = 'Person'
      end
    end

    def get_field
      if !self[__callee__].nil? && (self[__callee__] != [])
        self[__callee__]
      elsif extracted[__callee__.to_s]
        self[__callee__] = extracted[__callee__.to_s]
      end
    end
    alias start_period get_field
    alias end_period get_field
    alias establishment_date get_field
    alias termination_date get_field

    # collect pub counts for this org and any subordinates
    # Don't do this on "United States" !
    def pub_count
      self['pub_count'] = count
      predecessors.each do |pred|
        p = begin
              Authority.find_by(name: pred)
            rescue StandardError
              nil
            end
        unless p.nil?
          self['pub_count'] += p.pub_count
          p.save
        end
      end
      subOrganization.each do |sub|
        s = begin
              Authority.find_by(name: sub)
            rescue StandardError
              nil
            end
        next if s.nil?
        # will recursively call pub_count on subs
        self['pub_count'] += s.pub_count
        s.save
      end
      self['pub_count']
    end

    # search for a given name
    def self.search(name)
      # prefer names
      auth = begin
               Authority.find_by(name: name.chomp('.'))
             rescue StandardError
               nil
             end
      if auth.nil?
        auth = Authority.where(alternate_names: name.chomp('.')).limit(1).first
      end
      if auth.nil?
        auth = Authority.where(predecessors: name.chomp('.')).limit(1).first
      end
      if auth.nil?
        auth = Authority.where(successors: name.chomp('.')).limit(1).first
      end
      auth
    end

    # handles 4xx and 5xx
    def tracings
      if (self[__callee__] == []) && @tracings.nil? && !marc.nil?
        @tracings = { superiors: [],
                      subordinates: [],
                      successors: [],
                      predecessors: [],
                      employers: [],
                      alternate_names: [],
                      parents_calculated: [] }
        marc_record.each_by_tag(%w[400 410 451 500 510]) do |f|
          codes = %w[a b c n t d]
          pieces = f.find_all { |sub| codes.include? sub.code }.collect(&:value)
          this_record = pieces.join(' ')
          if /h..rarc.*al superior/i.match?(f['i']) ||
             /^t/.match?(f['w'])
            @tracings[:superiors] << this_record.chomp('.')
          elsif /h..rarc.+al subordinate/u.match?(f['i'])
            @tracings[:subordinates] << this_record.chomp('.')
          elsif /suc*es*or/i.match?(f['i']) ||
                /product of merger/i.match?(f['i']) ||
                /product of split/i.match?(f['i']) ||
                /succeeded by/i.match?(f['i']) ||
                /^b/.match?(f['w'])
            @tracings[:successors] << this_record.chomp('.')
          elsif /predecessor/i.match?(f['i']) ||
                /preceded by/i.match?(f['i']) ||
                /mergee/i.match?(f['i']) ||
                /component of merger/i.match?(f['i']) ||
                /absorbed corporate body/i.match?(f['i']) ||
                /^a/.match?(f['w'])
            @tracings[:predecessors] << this_record.chomp('.')
          elsif /employer/i.match?(f['i'])
            @tracings[:employers] << this_record.chomp('.')
          else
            @tracings[:alternate_names] << this_record.chomp('.')
            if f.tag == '410' # and f.indicator1 == '1'
              p = parent_from_tracings pieces
              (@tracings[:parents_calculated] << p).uniq! unless p.nil?
            end
            if alternate_length < pieces.count
              self.alternate_length = pieces.count
            end
          end
        end
      end
      unless @tracings.nil?
        self[__callee__] = @tracings[__callee__].uniq
        self[__callee__] ||= []
      end
      self[__callee__]
    end
    alias parents_calculated tracings
    alias predecessors tracings
    alias successors tracings
    alias subordinates tracings
    alias superiors tracings
    alias alternate_names tracings
    alias employers tracings
  end
end
