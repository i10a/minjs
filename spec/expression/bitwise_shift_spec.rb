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
  end
end
