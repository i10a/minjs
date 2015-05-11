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
  end
end
