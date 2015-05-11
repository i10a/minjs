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
  end
end
