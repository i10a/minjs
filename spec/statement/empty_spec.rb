require 'spec_helper'

describe 'Statement' do
  describe 'Empty' do
    it 'is empty statement' do
      js = test_parse <<-EOS
;
EOS
      expect(js).to eq ""
    end
  end
end
