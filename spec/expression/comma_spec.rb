# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Comma' do
    it 'is comma operator' do
      js = test_parse <<-EOS
a=1,b=a+1,c=b*2
EOS
      expect(js).to eq "a=1,b=a+1,c=b*2;"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse '1,'
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end
