# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Multiplicative' do
    it 'is multiplicative operator' do
      js = test_parse <<-EOS
1*2
2/3
2%3
EOS
      expect(js).to eq "1*2;2/3;2%3;"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse 'a*'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a/'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a%'
      }.to raise_error(Minjs::ParseError)
    end
  end
end
