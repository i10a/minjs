# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Equality' do
    it 'is equality operator' do
      js = test_parse <<-EOS
a=0
b=false
a == b;
a != b;
a === b;
a !== b;
for(var i=(a==b);false;);
for(var i=(a!=b);false;);
for(var i=(a===b);false;);
for(var i=(a!==b);false;);
EOS
      expect(js).to eq "a=0;b=false;a==b;a!=b;a===b;a!==b;for(var i=(a==b);false;);for(var i=(a!=b);false;);for(var i=(a===b);false;);for(var i=(a!==b);false;);"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse 'a=='
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse 'a!='
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse 'a==='
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse 'a!=='
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end
