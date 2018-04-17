# frozen_string_literal: true

require_relative '../lib/nauth'
require 'dotenv'
Dotenv.load
Mongoid.load!('config/mongoid.yml', :production)
Mongo::Logger.logger.level = ::Logger::FATAL
Authority = Nauth::Authority

def get_child(child)
  unless @auths_seen.keys.include? child
    @auths_seen[child] = 1
    Authority.where(name: child).each do |c|
      puts [c.sameAs, child, c['parents'].join(', ')].join("\t")
      c.children.each do |childs_child|
        get_child childs_child
      end
    end
  end
end

@auths_seen = {}

# start at 'United States.' root
@root = Authority.find_by(name: 'United States')

@root.children.each do |child|
  get_child child
end
