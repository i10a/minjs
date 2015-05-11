# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'Array' do
    it 'is array literal' do
      js = test_parse <<-EOS
a=[1,2,3]
b=["a","b","c"]
c=[1,,3]
d=[1,2,3,]
EOS
      expect(js).to eq "a=[1,2,3];b=[\"a\",\"b\",\"c\"];c=[1,,3];d=[1,2,3];"
    end
  end
end
