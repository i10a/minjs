# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'BinaryLogical' do
    it 'is binary logical operator' do
      js = test_parse <<-EOS
123 && 456;
456 || 123;
for(var i=(123&&456);false;);
for(var i=(123||456);false;);
EOS
      expect(js).to eq "123&&456;456||123;for(var i=(123&&456);false;);for(var i=(123||456);false;);"
    end
  end
end
