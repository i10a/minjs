# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Postfix' do
    it 'is postinc or postdec operator' do
      js = test_parse <<-EOS
a++
b--
c
EOS
      expect(js).to eq "a++;b--;c;"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse '++'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse '--'
      }.to raise_error(Minjs::ParseError)
    end
  end
end
