# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'IfToReturn2' do
    it 'convert if statment to return statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;return c;
EOS
      js = c.if_to_return2.to_js
      expect(js).to eq "return a?b:c;"
    end

    it 'convert if statment to return statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;
if(c)return d;
if(e)return f;
EOS
      js = c.if_to_return2.to_js
      expect(js).to eq "return a?b:c?d:e?f:void 0;"
    end
  end
end

