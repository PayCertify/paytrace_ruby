require 'paytrace'

# see: http://help.paytrace.com/api-email-receipt for details

#
# Helper that loops through the response values and dumps them out
#
def dump_response_values(response)
  if(response.has_errors?)
    response.errors.each do |key, value|
      puts "#{key.ljust(20)}#{value}"
    end
  else
    response.values.each do |key, value|
      puts "#{key.ljust(20)}#{value}"
    end
  end
end

def log(msg)
  puts ">>>>>> #{msg}"
end

PayTrace.configure do |config|
  config.user_name = "demo123"
  config.password = "demo123"
  config.domain = "stage.paytrace.com"
end

# this should be a valid credit card number (it can be a "sandbox" number, however)
cc = PayTrace::CreditCard.new({
  card_number: "4111111111111111",
  expiration_month: 12,
  expiration_year: 2014
  })
ba = PayTrace::Address.new({
  name: "John Doe",
  street: "1234 Main Street",
  street2: "Apartment 1B",
  city: "Shoreline",
  state: "WA",
  country: "US",
  postal_code: "98133",
  address_type: :billing
  })
extra = {
  email: "support@paytrace.com",
  phone: "206-555-1212",
  fax: "206-555-1313",
  password: "foxtrot123",
  account_number: 123456789,
  routing_number: 12345678,
  discretionary_data: "Discretionary data."
}

PayTrace::API::Gateway.debug = true

begin
  log "Attempting to remove existing customer 'john_doe'..."
  c = PayTrace::Customer.new("john_doe")
  c.delete()
rescue PayTrace::Exceptions::ErrorResponse
  log "No such cusomter... continuing..."
end

log "Creating customer john_doe..."
c = PayTrace::Customer.from_cc_info({customer_id: "john_doe", credit_card: cc, billing_address: ba}.merge(extra))
log "Customer ID: #{c.id}"
dump_response_values(PayTrace::API::Gateway.last_response)

log "Creating recurrence for john_doe..."
params = {
  customer_id: "john_doe",
  recur_frequency: "3",
  recur_start: "4/22/2016",
  recur_count: 999,
  amount: 9.99,
  transaction_type: "sale",
  description: "Recurring transaction",
  recur_receipt: "Y",
  recur_type: "A"
}
recur_id = PayTrace::RecurringTransaction.create(params)
puts ">>>>>>> Recurrence ID: #{recur_id}"

log "Deleting recurrence #{recur_id}..."
PayTrace::RecurringTransaction.delete({recur_id: recur_id})

log "Deleting customer 'john_doe'..."
c.delete()