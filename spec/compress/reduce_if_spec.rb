# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReduceIf' do
    it 'reduce nested "if" statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)
if(b)
break;
EOS
      js = c.reduce_if.to_js
      expect(js).to eq "if(a&&b)break;"
    end
  end
end
