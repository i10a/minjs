# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Conditional' do
    it 'is conditional operator' do
      js = test_parse <<-EOS
a=1?b=2:c=3
EOS
      expect(js).to eq "a=1?b=2:c=3;"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse '1?a:'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '1?'
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end
