# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Additive' do
    it 'is additive operator' do
      js = test_parse <<-EOS
1+2
2-3
EOS
      expect(js).to eq "1+2;2-3;"
    end
  end
end
