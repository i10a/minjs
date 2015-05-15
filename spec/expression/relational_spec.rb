# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Relational' do
    it 'is relational operator' do
      js = test_parse <<-EOS
a=0
b=10
a < b;
a > b;
a <= b;
a >= b;
a instanceof b;
a in b;
for(var i=(a<b);false;);
for(var i=(a>b);false;);
for(var i=(a<=b);false;);
for(var i=(a>=b);false;);
for(var i=(a instanceof b);false;);
EOS
      expect(js).to eq "a=0;b=10;a<b;a>b;a<=b;a>=b;a instanceof b;a in b;for(var i=(a<b);false;);for(var i=(a>b);false;);for(var i=(a<=b);false;);for(var i=(a>=b);false;);for(var i=(a instanceof b);false;);"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse 'a<'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'b>'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a<='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'b>='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a instanceof'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'b in'
      }.to raise_error(Minjs::ParseError)
    end
  end
end
