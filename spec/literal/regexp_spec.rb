# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'Regexp' do
    it 'is regexp literal' do
      js = test_parse <<-'EOS'
a=/abc/;
b=/a\bc/;
c=/a\/c/;
d=/a[bc]d/;
e=/a[\bc]d/;
f=/a[\bc/]d/;
a=/abc/g;
b=/a\bc/g;
c=/a\/c/g;
d=/a[bc]d/g;
e=/a[\bc]d/g;
f=/a[\bc/]d/g;
EOS
      expect(js).to eq "a=/abc/;b=/a\\bc/;c=/a\\/c/;d=/a[bc]d/;e=/a[\\bc]d/;f=/a[\\bc/]d/;a=/abc/g;b=/a\\bc/g;c=/a\\/c/g;d=/a[bc]d/g;e=/a[\\bc]d/g;f=/a[\\bc/]d/g;"
    end
  end
end
