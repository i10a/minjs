require 'spec_helper'

describe 'Statement' do
  describe 'Switch' do
    it 'is switch statement' do
      js = test_parse <<-EOS
$=0;
switch($)
{
        case 0:
        console.log(0);
        break;

        case 1:
        console.log(1);
        break;

	case 2:
        default:
        console.log("default");
        break;
}
EOS
      expect(js).to eq "$=0;switch($){case 0:console.log(0);break;case 1:console.log(1);break;case 2:default:console.log(\"default\");break}";
    end

    it 'is switch statement' do
      js = test_parse <<-EOS
switch($)
{
        case 0:
        default:
        case 1:
}
EOS
      expect(js).to eq "switch($){case 0:default:case 1:}"
    end

    it 'is empty switch statement' do
      js = test_parse <<-EOS
switch($)
{
}
EOS
      expect(js).to eq "switch($){}"
    end

    it 'raise exception' do
      expect {
        js = test_parse <<-EOS
switch($)// {} are required
;
EOS
      }.to raise_error(Minjs::ParseError)
    end
  end
end
