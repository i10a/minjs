# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'White space' do
    it 'is white space' do
      js = test_parse "a\u00a0=\u205f1;b\u3000=\t2;"
      expect(js).to eq ("a=1;b=2;")
    end
  end
end
