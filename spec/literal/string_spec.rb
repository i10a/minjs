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
      expect(js).to eq('a="";a="abc";a="a\nbc";a="aBc";a="aBc";a="aBc";a="あいうえお";')
    end

    it 'is string literal' do
      js = test_parse <<-'EOS'
a=''
a='abc'
a='a\nbc'
a='a\u0042c'
a='a\x42c'
a='a\102c'
a='あいうえお'
EOS
      expect(js).to eq('a="";a="abc";a="a\nbc";a="aBc";a="aBc";a="aBc";a="あいうえお";')
    end

    it 'handles octal literals correctly' do
      js = test_parse <<-'EOS'
a = '\0'
a = "\10"
a = "\100"
a = "\1000"
EOS
      expect(js).to eq("a=\"\\0\";a=\"\\b\";a=\"@\";a=\"@0\";")
    end

    it 'handles literals correctly' do
      js = test_parse <<-'EOS'
'\2459' //9 is source character
'\412' //2 is source character
'\128' //8 is source character
EOS
      expect(js).to eq('"¥9";"!2";"\n8";')

    end

    it 'is line continuation' do
      js = test_parse <<-'EOS'
a="a\
b"
EOS
      expect(js).to eq("a=\"ab\";")
    end

    it 'prefer to single quote ' do
      js = test_parse <<-'EOS'
a="\"\"\"\'"
EOS
      expect(js).to eq("a='\"\"\"\\\'';")
    end
  end
end
