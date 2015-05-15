# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Grouping' do
    it 'convert sequence of statement to single expression statement' do
      c = test_compressor
      c.parse <<-EOS
if(true){
;
a=1;
;
b=2;
c=3;
d=4;
}
EOS
      js = c.grouping_statement.to_js
      expect(js).to eq "if(true){a=1,b=2,c=3,d=4}"
    end
  end
end

