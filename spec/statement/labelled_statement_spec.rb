require 'spec_helper'

describe 'Statement' do
  describe 'Labelled' do
    it 'is labelled statement' do
      js = test_parse 'aaa:while(true);'
      expect(js).to eq "aaa:while(true);"
    end

    it 'cause syntax error' do
      expect {
        js = test_parse <<-'EOS'
this://this is reserved word
while(true);
EOS
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end
