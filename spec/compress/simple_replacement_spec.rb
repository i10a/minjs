# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'SimpleReplacement' do
    it 'replacement' do
      c = test_compressor
      c.parse <<-EOS
true;
false;
if(1)a;
if(0)a;
if(0)a;else b;
while(1);
EOS
      js = c.simple_replacement.to_js
      expect(js).to eq "(!0);(!1);a;b;for(;;);"
    end
  end
end

