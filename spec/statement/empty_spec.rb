require 'spec_helper'

describe 'Statement' do
  describe 'Empty' do
    it 'is empty statement' do
      js = test_parse <<-EOS
;
EOS
      expect(js).to eq ""
    end
    it 'is empty statement' do
      js = test_parse <<-EOS
while(a)
  if(a)
    ;
  else
    ;
EOS
      expect(js).to eq "while(a)if(a);else;"
    end
  end
end
