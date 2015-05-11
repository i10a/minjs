require 'spec_helper'

describe 'Statement' do
  describe 'Return' do
    it 'is return statement' do
      js = test_parse <<-EOS
function a(){
return
}
EOS
      expect(js).to eq "function a(){return};"
    end

    it 'is return statement with value' do
      js = test_parse <<-EOS
function a(){
return 1
}
EOS
      expect(js).to eq "function a(){return 1};"
    end

    it 'is return statement without automatic semicolon insertion' do
      js = test_parse <<-EOS
function a(){
return 1
+2
}
EOS
      expect(js).to eq "function a(){return 1+2};"
    end

    it 'is return statement with automatic semicolon insertion' do
      js = test_parse <<-EOS
function a(){
return
1+2
}
EOS
      expect(js).to eq "function a(){return;1+2};"
    end
  end
end
