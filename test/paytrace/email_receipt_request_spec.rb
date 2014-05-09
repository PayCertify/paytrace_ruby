require File.expand_path(File.dirname(__FILE__) + '../../test_helper.rb')

describe PayTrace::EmailReceiptRequest do
  before do
    PayTrace::API::Gateway.debug = true
    PayTrace::API::Gateway.next_response = "RESPONSE~ok|CUSTOMERID~12345|CUSTID~john_doe"
  end

  it "correctly formats the request URL" do
    PayTrace::EmailReceiptRequest.create({email: "support@paytrace.com", transaction_id: "FOO1234"})

    PayTrace::API::Gateway.last_request.must_equal "UN~#{PayTrace.configuration.user_name}|PSWD~#{PayTrace.configuration.password}|TERMS~Y|METHOD~EmailReceipt|TRANXID~FOO1234|EMAIL~support@paytrace.com|"
  end

  it "uses check id instead of transaction id if specified" do
    PayTrace::EmailReceiptRequest.create({email: "support@paytrace.com", check_id: "CHECK2345"})

    PayTrace::API::Gateway.last_request.must_equal "UN~#{PayTrace.configuration.user_name}|PSWD~#{PayTrace.configuration.password}|TERMS~Y|METHOD~EmailReceipt|CHECKID~CHECK2345|EMAIL~support@paytrace.com|"
  end
end
