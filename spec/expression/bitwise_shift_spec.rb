# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'BitwiseShift' do
    it 'is bitwise shift operator' do
      js = test_parse <<-EOS
123 << 1;
456 >> 2;
789 >>> 3;
EOS
      expect(js).to eq "123<<1;456>>2;789>>>3;"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse '1<<'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '1>>'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '1>>>'
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end
