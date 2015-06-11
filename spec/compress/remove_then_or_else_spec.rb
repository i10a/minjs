# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'RemoveThenOrElse' do
    it 'remove else clause' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;else c;
EOS
      js = c.remove_then_or_else.to_js
      expect(js).to eq "if(a)return b;c;"
    end

    it 'remove then clause' do
      c = test_compressor
      c.parse <<-EOS
if(a)b;else return c;
EOS
      js = c.remove_then_or_else.to_js
      expect(js).to eq "if(!a)return c;b;"
    end
end
end
