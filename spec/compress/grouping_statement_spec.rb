# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'GroupingStatement' do
    it 'convert sequence of statement to single expression statement' do
      c = test_compressor
      c.parse <<-EOS
a=1;b=2;c=3;while(true);new a();f(g);this.a()?c:d;d=1,e=1;
EOS
      js = c.grouping_statement.to_js
      expect(js).to eq "a=1,b=2,c=3;while(true);new a(),f(g),this.a()?c:d,(d=1,e=1);"
    end

    it 'convert sequence of statement to single expression statement' do
      c = test_compressor
      c.parse <<-EOS
a=1;b=2;c=3;return a;
EOS
      js = c.grouping_statement.to_js
      expect(js).to eq "return a=1,b=2,c=3,a;"
    end

    it 'convert sequence of statement to single expression statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;return c;
EOS
      js = c.optimize_if_return.to_js
      expect(js).to eq "if(a)return b;else return c;"
    end
  end
end

