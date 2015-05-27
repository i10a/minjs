# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'IfToCond' do
    it 'convert if statement to conditonal expression' do
      c = test_compressor
      c.parse <<-EOS
if(a)b;else c;
if(a)b;
if(!a)b;else c;
if(!a)b;
EOS
      js = c.if_to_cond.to_js
      expect(js).to eq "a?b:c;a&&b;a?c:b;a||b;"
    end
    it 'convert if statement to return statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;else return c;
EOS
      js = c.if_to_cond.to_js
      expect(js).to eq "return a?b:c;"
    end
    it 'prefer conditonal operator than logical and/or' do
      c = test_compressor
      c.parse <<-EOS
if(x)a=b?c=d:e=f;
EOS
      js = c.if_to_cond.to_js
      expect(js).to eq "x?a=b?c=d:e=f:0;"
    end
  end
end

