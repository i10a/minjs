$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minjs'
require 'minjs/compressor/compressor'
require 'logger'

def test_compressor
  Minjs::Compressor::Compressor.new(:debug_level => Logger::WARN)
end

def test_parse(str)
  test_compressor.parse(str).to_js
end
