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
  end
end
