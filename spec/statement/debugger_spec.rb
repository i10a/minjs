require 'spec_helper'

describe 'Statement' do
  describe 'Debugger' do
    it 'is debugger statement' do
      js = test_parse <<-EOS
debugger;
EOS
      expect(js).to eq "debugger;"
    end
  end
end
