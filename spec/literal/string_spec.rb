# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'String' do
    it 'is string literal' do
      js = test_parse <<-'EOS'
a=""
a="abc"
a="a\nbc"
a="a\u0042c"
a="a\x42c"
a="a\102c"
a="あいうえお"
EOS
      expect(js).to eq('a="";a="abc";a="a\nbc";a="aBc";a="aBc";a="aB";a="あいうえお";')
    end
  end
end
