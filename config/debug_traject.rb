# frozen_string_literal: true

require 'pp'
require 'traject/json_writer'

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
  provide 'writer_class_name', 'Traject::JsonWriter'
  provide 'output_file', 'out.json'
  provide 'reader_class_name', 'Traject::NDJReader'
  provide 'marc_source.type', 'json'
end

to_field 'fiveteni', extract_marc('410i:510i')
to_field 'fivetenw', extract_marc('410i:510w')
