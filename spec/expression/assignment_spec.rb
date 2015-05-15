# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Assignment' do
    it 'is assignment operator' do
      js = test_parse <<-EOS
a=1
a*=2
a/=3
a%=4
a+=5
a-=6
a<<=7
a>>=8
a>>>=9
a&=10
a^=11
a|=12
EOS
      expect(js).to eq "a=1;a*=2;a/=3;a%=4;a+=5;a-=6;a<<=7;a>>=8;a>>>=9;a&=10;a^=11;a|=12;"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse 'a='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a*='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a/='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a%='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a+='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a-='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a<<='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a>>='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a>>>='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a&='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a|='
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a^='
      }.to raise_error(Minjs::ParseError)
    end
  end
end
