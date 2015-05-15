# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'BinaryBitwise' do
    it 'is binary bitwise operator' do
      js = test_parse <<-EOS
123 & 456;
456 ^ 123;
789 | 123;
for(var i=(123&456);false;);
for(var i=(123^456);false;);
for(var i=(123|456);false;);
EOS
      expect(js).to eq "123&456;456^123;789|123;for(var i=(123&456);false;);for(var i=(123^456);false;);for(var i=(123|456);false;);"
    end

    it 'cause syntax error' do
      expect {
        js = test_parse '1&'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse '1^'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse '1|'
      }.to raise_error(Minjs::ParseError)
    end
  end
end
