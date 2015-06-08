# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Primary' do
    it 'is primary expression' do
      js = test_parse <<-EOS
this;
hoge;
123;
"456";
[1,2,3];
+{a:b, c:d, e:f}
(1+2+3)
EOS
      expect(js).to eq "this;hoge;123;\"456\";[1,2,3];+{a:b,c:d,e:f}(1+2+3);"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse '()'
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end
