require 'pp'

# A sample traject configration, save as say `traject_config.rb`, then
# run `traject -c traject_config.rb marc_file.marc` to index to
# solr specified in config file, according to rules specified in
# config file


# To have access to various built-in logic
# for pulling things out of MARC21, like `marc_languages`
require 'traject/macros/marc21_semantics'
extend  Traject::Macros::Marc21Semantics

# To have access to the traject marc format/carrier classifier
require 'traject/macros/marc_format_classifier'
extend Traject::Macros::MarcFormats

# In this case for simplicity we provide all our settings, including
# solr connection details, in this one file. But you could choose
# to separate them into antoher config file; divide things between
# files however you like, you can call traject with as many
# config files as you like, `traject -c one.rb -c two.rb -c etc.rb`
settings do
  #provide "solr.url", "http://solr-sdr-usfeddocs-dev:9032/usfeddocs/collection1"
  provide "reader_class_name", "Traject::NDJReader"
  provide "marc_source.type", "json"
end

# name
to_field "corp_name", extract_marc("110abntd", :separator => "\t")
to_field "title", extract_marc("110t")
to_field "name", extract_marc("100abcd")

# alternateName
to_field "alternateName",          extract_marc("400abcd:500abcd")

# sameAs
to_field "sameAs", extract_marc("010a")

#046 coded dates
to_field "start_period", extract_marc("046s")
to_field "end_period", extract_marc("046t")
to_field "establishment_date", extract_marc("046q")
to_field "termination_date", extract_marc("046r")
