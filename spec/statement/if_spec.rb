require 'spec_helper'

describe 'Statement' do
  describe 'If' do
    it 'is if-then statement' do
      js = test_parse <<-EOS
if(true)
console.log(true)
EOS
      expect(js).to eq "if(true)console.log(true);"
    end
    it 'is if-then-block statement' do
      js = test_parse <<-EOS
if(true){
console.log(true)
}
EOS
      expect(js).to eq "if(true){console.log(true)};"
    end
    it 'is if-then-else statement' do
      js = test_parse <<-EOS
if(false)
console.log(true)
else
console.log(false)
EOS
      expect(js).to eq "if(false)console.log(true);else console.log(false);"
    end
    it 'is if-then-else-block statement' do
      js = test_parse <<-EOS
if(false)
console.log(true)
else{
console.log(false)
}
EOS
      expect(js).to eq "if(false)console.log(true);else{console.log(false)};"
    end
  end
end
