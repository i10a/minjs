require 'spec_helper'

describe 'Statement' do
  describe 'Throw' do
    it 'is throw statement' do
      js = test_parse <<-EOS
try{
throw 'a'
}
catch(e){
console.log(e)
}
EOS
      expect(js).to eq "try{throw\"a\"}catch(e){console.log(e)};"
    end
  end
end
