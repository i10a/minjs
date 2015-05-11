$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minjs'

def test_parse(str)
  Minjs::Compressor.new.parse(str).to_js
end
