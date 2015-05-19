# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'Comment' do
    it 'is singleline comment literal' do
      js = test_parse <<-EOS
// singleline
// singleline (no lt)
EOS
      expect(js).to eq ("")
    end

    it 'is multiline comment literal' do
      js = test_parse <<-EOS
/* single line */
/*
multiline
*/
EOS
      expect(js).to eq ("")
    end

    it 'is multiline comment and treated as white space' do
      js = test_parse <<-EOS
return /* multiline */1+2
EOS
      expect(js).to eq("return 1+2;")
    end

    it 'is multiline comment and treated as line terminator' do
      js = test_parse <<-EOS
return /* multiline
*/1+2
EOS
      expect(js).to eq("return;1+2;")
    end
  end
end
