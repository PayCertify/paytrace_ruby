require 'paytrace/api/request'
require 'paytrace/api/gateway'
require 'paytrace/address'
require 'base64'

module PayTrace
  # Manages transaction-related functionality
  class Transaction
    # :nodoc:
    TRANSACTION_METHOD = "PROCESSTRANX"
    EXPORT_TRANSACTIONS_METHOD = "ExportTranx"
    EXPORT_TRANSACTIONS_RESPONSE = "TRANSACTIONRECORD"
    ATTACH_SIGNATURE_METHOD = "AttachSignature"
    CALCULATE_SHIPPING_COST = "CalculateShipping"
    CALCULATE_SHIPPING_COST_RESPONSE = "SHIPPINGRECORD"
    LEVEL_3_VISA_METHOD = "Level3Visa"
    LEVEL_3_MC_METHOD = "Level3MCRD"
    SETTLE_TRANSACTION_METHOD = "SettleTranx"
    ADJUST_AMOUNT_METHOD = "AdjustAmount"

    SWIPED_SALE_REQUEST_REQUIRED = [
      :transaction_type,
      :amount,
      :swipe
    ]

    SWIPED_SALE_REQUEST_OPTIONAL = []

    KEYED_SALE_REQUEST_REQUIRED = [
      :transaction_type,
      :amount,
      :card_number,
      :expiration_month,
      :expiration_year
    ]

    KEYED_SALE_REQUEST_OPTIONAL = []

    CUSTID_SALE_REQUEST_REQUIRED = [
      :transaction_type,
      :amount,
      :customer_id
    ]

    BILLING_AND_SHIPPING_ADDRESS_FIELDS = [
      :billing_name,
      :billing_address,
      :billing_address2,
      :billing_city,
      :billing_state,
      :billing_postal_code,
      :billing_country,
      :shipping_name,
      :shipping_address,
      :shipping_address2,
      :shipping_city,
      :shipping_state,
      :shipping_postal_code,
      :shipping_region,
      :shipping_country
    ]

    ADDRESSES_AND_EXTRA = BILLING_AND_SHIPPING_ADDRESS_FIELDS + [
      :email,
      :csc,
      :invoice,
      :description,
      :tax_amount,
      :customer_reference_id,
      :discretionary_data
    ]

    ALL_OPTIONAL_FIELDS = ADDRESSES_AND_EXTRA + [
      :return_clr,
      :custom_dba,
      :enable_partial_authentication
    ]

    CUSTID_SALE_REQUEST_OPTIONAL = ALL_OPTIONAL_FIELDS

    REFERENCED_SALE_REQUEST_REQUIRED = [
      :transaction_type,
      :amount
    ]

    REFERENCED_SALE_REQUEST_OPTIONAL = [
    ]

    REFUND_OPTIONAL = ADDRESSES_AND_EXTRA + [:amount]

    STORE_AND_FORWARD_OPTIONAL = ALL_OPTIONAL_FIELDS + [:store_forward_date]

    CASH_ADVANCE_REQUIRED = [
      :transaction_type,
      :amount,
      :cash_advance,
      :id_number,
      :id_expiration,
      :cc_last_4,
      :billing_name,
      :billing_address,
      :billing_address2,
      :billing_city,
      :billing_state,
      :billing_postal_code
    ]

    CASH_ADVANCE_OPTIONAL = [
      :billing_country,
      :shipping_name,
      :shipping_address,
      :shipping_address2,
      :shipping_city,
      :shipping_region,
      :shipping_state,
      :shipping_postal_code,
      :email,
      :csc,
      :invoice,
      :description,
      :tax_amount,
      :customer_reference_id
    ]
    # :doc:

    # See http://help.paytrace.com/api-sale
    #
    # Creates a sale transaction using a keyed in credit card.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:card_number* -- the credit card number used
    # * *:expiration_month* -- the expiration month of the credit card
    # * *:expiration_year* -- the expiration year of the credit card
    def self.keyed_sale(params, cfg)
      send_transaction(params, TransactionTypes::SALE, KEYED_SALE_REQUEST_REQUIRED, KEYED_SALE_REQUEST_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-sale
    #
    # Creates a sale transaction using a swiped in credit card.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:swipe* -- credit card swipe data (card swiped sales)
    def self.swiped_sale(params, cfg)
      send_transaction(params, TransactionTypes::SALE, SWIPED_SALE_REQUEST_REQUIRED, SWIPED_SALE_REQUEST_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-sale
    #
    # Creates a sale transaction using a swiped in credit card.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:customer_id* -- the customer ID to reference for this sale
    #
    # Optional parameters:
    #
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:shipping_country* -- the shipping country for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    # * *:discretionary_data* -- a hash of optional discretionary data to attach to this transaction
    # * *:return_clr* -- if set to "Y", card level results will be returned w/ the response. Card level results include whether or not the card is a consumer, purchasing, check, rewards, etc. account. Card level results are only returned with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, Global, Paymentech, and Trident networks.(customer ID token sale)
    # * *:custom_dba* -- optional value that is sent to the cardholder’s issuer and overrides the business name stored in PayTrace. Custom DBA values are only used with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, and Trident networks (customer ID token sale)
    # * *:enable_partial_authentication* -- flag that must be set to ‘Y’ in order to support partial authorization and balance amounts in transaction responses (customer ID token sale)
    def self.customer_id_sale(params, cfg)
      send_transaction(params, TransactionTypes::SALE, CUSTID_SALE_REQUEST_REQUIRED, CUSTID_SALE_REQUEST_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-authorizations
    #
    # Performs an authorization using a keyed in credit card.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:card_number* -- the credit card number used
    # * *:expiration_month* -- the expiration month of the credit card
    # * *:expiration_year* -- the expiration year of the credit card
    def self.keyed_authorization(params, cfg)
      send_transaction(
        params,
        TransactionTypes::Authorization,
        [:transaction_type, :amount, :card_number, :expiration_month, :expiration_year],
        [], cfg)
    end

    # See http://help.paytrace.com/api-authorizations
    #
    # Performs an authorization using a stored customer id.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:customer_id* -- the customer ID to reference for this authorization
    def self.customer_id_authorization(params, cfg)
      send_transaction(params, TransactionTypes::Authorization, [:transaction_type, :amount, :customer_id], [], cfg)
    end

    # See http://help.paytrace.com/api-refunds
    #
    # Performs a refund using swiped credit card data.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:swipe* -- credit card swipe data (card swiped sales)
    #
    # Optional parameters:
    #
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:shipping_country* -- the shipping country for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    # * *:discretionary_data* -- a hash of optional discretionary data to attach to this transaction
    # * *:return_clr* -- if set to "Y", card level results will be returned w/ the response. Card level results include whether or not the card is a consumer, purchasing, check, rewards, etc. account. Card level results are only returned with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, Global, Paymentech, and Trident networks.(customer ID token sale)
    # * *:custom_dba* -- optional value that is sent to the cardholder’s issuer and overrides the business name stored in PayTrace. Custom DBA values are only used with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, and Trident networks (customer ID token sale)
    # * *:enable_partial_authentication* -- flag that must be set to ‘Y’ in order to support partial authorization and balance amounts in transaction responses (customer ID token sale)
    def self.swiped_refund(params, cfg)
      send_transaction(params, TransactionTypes::Refund, [:transaction_type, :amount, :swipe], REFUND_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-refunds
    #
    # Performs a refund using keyed-in credit card data.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:card_number* -- the credit card number used
    # * *:expiration_month* -- the expiration month of the credit card
    # * *:expiration_year* -- the expiration year of the credit card
    #
    # _Note:_ optional parameters are identical to those for swiped_refund
    def self.keyed_refund(params, cfg)
      send_transaction(
        params,
        TransactionTypes::Refund,
        [:transaction_type, :amount, :card_number, :expiration_month, :expiration_year],
        REFUND_OPTIONAL, cfg)
    end


    # See http://help.paytrace.com/api-refunds
    #
    # Performs a refund using a customer ID as a reference.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:customer_id -- the customer ID for the refund
    #
    # _Note:_ optional parameters are identical to those for swiped_refund
    def self.customer_id_refund(params, cfg)
      send_transaction(
        params,
        TransactionTypes::Refund,
        [:transaction_type, :amount, :customer_id],
        REFUND_OPTIONAL, cfg)
    end


    # See http://help.paytrace.com/api-refunds
    #
    # Performs a refund using a transaction ID as a reference.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the transaction
    # * *:transaction_id -- the customer ID for the refund
    #
    # _Note:_ optional parameters are identical to those for swiped_refund
    def self.transaction_id_refund(params, cfg)
      send_transaction(
        params,
        TransactionTypes::Refund,
        [:transaction_type, :transaction_id],
        REFUND_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-void
    #
    # Performs a void request.
    #
    # Required parameters:
    #
    # * *:transaction_id* -- the transaction ID to void
    def self.void(params, cfg)
      send_transaction(params, TransactionTypes::Void, [:transaction_type, :transaction_id], [], cfg)
    end

    # See http://help.paytrace.com/api-forced-sale
    #
    # Performs a forced approval sale using swiped credit card data.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the forced sale
    # * *:swipe* -- credit card swipe data (card swiped sales)
    # * *:approval_code* -- the approval code obtained external to the PayTrace system
    def self.swiped_forced_sale(params, cfg)
      send_transaction(
        params,
        TransactionTypes::ForcedSale,
        [:transaction_type, :amount, :swipe, :approval_code],
        ADDRESSES_AND_EXTRA, cfg)
    end

    # See http://help.paytrace.com/api-forced-sale
    #
    # Performs a forced approval sale using keyed-in credit card data.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the forced sale
    # * *:card_number* -- the credit card number used
    # * *:expiration_month* -- the expiration month of the credit card
    # * *:expiration_year* -- the expiration year of the credit card
    # * *:approval_code* -- the approval code obtained external to the PayTrace system
    def self.keyed_forced_sale(params, cfg)
      send_transaction(
        params,
        TransactionTypes::ForcedSale,
        [:transaction_type, :amount, :card_number, :expiration_month, :expiration_year, :approval_code],
        ADDRESSES_AND_EXTRA, cfg)
    end

    # See http://help.paytrace.com/api-forced-sale
    #
    # Performs a forced approval sale using a customer ID as a reference.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the forced sale
    # * *:customer_id -- the customer ID for the forced sale
    # * *:approval_code* -- the approval code obtained external to the PayTrace system
    def self.customer_id_forced_sale(params, cfg)
      send_transaction(
        params,
        TransactionTypes::ForcedSale,
        [:transaction_type, :amount, :customer_id, :approval_code],
        ADDRESSES_AND_EXTRA, cfg)
    end

    # See http://help.paytrace.com/api-forced-sale
    #
    # Performs a forced approval sale using a transaction ID as a reference.
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the forced sale
    # * *:transaction_id -- the transaction ID for the forced sale
    # * *:approval_code* -- the approval code obtained external to the PayTrace system
    def self.transaction_id_forced_sale(params, cfg)
      send_transaction(
        params,
        TransactionTypes::ForcedSale,
        [:transaction_type, :transaction_id, :approval_code],
        ADDRESSES_AND_EXTRA, cfg)
    end

    # See http://help.paytrace.com/api-capture
    #
    # Capturing a transaction updates an approved authorization to a pending settlement status that will initiate a transfer of funds. Processing a capture through the PayTrace API may only be accomplished by providing the transaction ID of the unsettled transaction that should be settled.
    #
    # Required parameters:
    #
    # * *transaction_id* -- the transaction ID to be captured
    def self.capture(params, cfg)
      send_transaction(
        params,
        TransactionTypes::Capture,
        [:transaction_type, :transaction_id],
        [], cfg)
    end

    # See http://help.paytrace.com/api-cash-advance
    #
    # Processing a Cash Advance transaction is similar to processing a Sale, however Cash Advances are special transactions that result in cash disbursements to the card holder. Consequently, additional information is required to process Cash Advances. Cash Advances should always be swiped unless your card reader is not able to reader the card’s magnetic stripe. Additionally, your PayTrace account must be specially configured to process this type of transaction.
    #
    # * *:amount* -- the amount of the cash advance
    # * *:swipe* -- swipe data provided with the cash advance
    # * *:id_number* -- the identification number of the photo ID used
    # * *:id_expiration* -- the expiration date of the photo ID
    # * *:cc_last_4* -- the last four digits of the credit card presented
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    #
    # Optional parameters:
    #
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    def self.swiped_cash_advance(params, cfg)
      send_transaction(
        {cash_advance: 'Y'}.merge(params),
        TransactionTypes::SALE,
        CASH_ADVANCE_REQUIRED + [:swipe],
        CASH_ADVANCE_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-cash-advance
    #
    # Processing a Cash Advance transaction is similar to processing a Sale, however Cash Advances are special transactions that result in cash disbursements to the card holder. Consequently, additional information is required to process Cash Advances. Cash Advances should always be swiped unless your card reader is not able to reader the card’s magnetic stripe. Additionally, your PayTrace account must be specially configured to process this type of transaction.
    #
    # * *:amount* -- the amount of the cash advance
    # * *:card_number* -- the credit card number used
    # * *:expiration_month* -- the expiration month of the credit card
    # * *:expiration_year* -- the expiration year of the credit card
    # * *:id_number* -- the identification number of the photo ID used
    # * *:id_expiration* -- the expiration date of the photo ID
    # * *:cc_last_4* -- the last four digits of the credit card presented
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    #
    # Optional parameters:
    #
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    def self.keyed_cash_advance(params, cfg)
      send_transaction(
        {cash_advance: 'Y'}.merge(params),
        TransactionTypes::SALE,
        CASH_ADVANCE_REQUIRED + [:card_number, :expiration_month, :expiration_year],
        CASH_ADVANCE_OPTIONAL, cfg)
      end

    # See http://help.paytrace.com/api-store-and-forward
    #
    # Processing a store & forward through the PayTrace API will request that the transaction is stored for future authorization for specified amount. Please note that the authorization of the store & forward may be scheduled by provided a StrFwdDate value or manually via the Virtual Terminal. *Note that swiped account numbers and CSC values are not stored. Only the card number and expiration dates are stored from the swipe.*
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the sale
    # * *:swipe* -- the swiped credit card information
    #
    # Optional parameters:
    #
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:shipping_country* -- the shipping country for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    # * *:discretionary_data* -- a hash of optional discretionary data to attach to this transaction
    # * *:return_clr* -- if set to "Y", card level results will be returned w/ the response. Card level results include whether or not the card is a consumer, purchasing, check, rewards, etc. account. Card level results are only returned with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, Global, Paymentech, and Trident networks.(customer ID token sale)
    # * *:custom_dba* -- optional value that is sent to the cardholder’s issuer and overrides the business name stored in PayTrace. Custom DBA values are only used with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, and Trident networks (customer ID token sale)
    # * *:enable_partial_authentication* -- flag that must be set to ‘Y’ in order to support partial authorization and balance amounts in transaction responses (customer ID token sale)
    # * *:store_forward_date* -- optional future date when the transaction should be authorized and settled. Only applicable if the TranxType is STR/FWD
    def self.swiped_store_forward(params, cfg)
      send_transaction(params, TransactionTypes::StoreForward, [:transaction_type, :amount, :swipe], STORE_AND_FORWARD_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-store-and-forward
    #
    # Processing a store & forward through the PayTrace API will request that the transaction is stored for future authorization for specified amount. Please note that the authorization of the store & forward may be scheduled by provided a StrFwdDate value or manually via the Virtual Terminal. *Note that swiped account numbers and CSC values are not stored. Only the card number and expiration dates are stored from the swipe.*
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the sale
    # * *:card_number* -- the credit card number
    # * *:expiration_month* -- the expiration month of the credit card
    # * *:expiration_year* -- the expiration year of the credit card
    #
    # Optional parameters:
    #
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:shipping_country* -- the shipping country for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    # * *:discretionary_data* -- a hash of optional discretionary data to attach to this transaction
    # * *:return_clr* -- if set to "Y", card level results will be returned w/ the response. Card level results include whether or not the card is a consumer, purchasing, check, rewards, etc. account. Card level results are only returned with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, Global, Paymentech, and Trident networks.(customer ID token sale)
    # * *:custom_dba* -- optional value that is sent to the cardholder’s issuer and overrides the business name stored in PayTrace. Custom DBA values are only used with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, and Trident networks (customer ID token sale)
    # * *:enable_partial_authentication* -- flag that must be set to ‘Y’ in order to support partial authorization and balance amounts in transaction responses (customer ID token sale)
    # * *:store_forward_date* -- optional future date when the transaction should be authorized and settled. Only applicable if the TranxType is STR/FWD
    def self.keyed_store_forward(params, cfg)
      send_transaction(
        params,
        TransactionTypes::StoreForward,
        [:transaction_type, :amount, :card_number, :expiration_month, :expiration_year],
        STORE_AND_FORWARD_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-store-and-forward
    #
    # Processing a store & forward through the PayTrace API will request that the transaction is stored for future authorization for specified amount. Please note that the authorization of the store & forward may be scheduled by provided a StrFwdDate value or manually via the Virtual Terminal. *Note that swiped account numbers and CSC values are not stored. Only the card number and expiration dates are stored from the swipe.*
    #
    # Required parameters:
    #
    # * *:amount* -- the amount of the sale
    # * *:customer_id* -- the customer ID for the sale
    #
    # Optional parameters:
    #
    # * *:billing_name* -- the billing name for this transaction
    # * *:billing_address* -- the billing street address for this transaction
    # * *:billing_address2* -- the billing street address second line (e.g., apartment, suite) for this transaction
    # * *:billing_city* -- the billing city for this transaction
    # * *:billing_state* -- the billing state for this transaction
    # * *:billing_postal_code* -- the billing zip code for this transaction
    # * *:billing_country* -- the billing country for this transaction
    # * *:shipping_name* -- the shipping name for this transaction
    # * *:shipping_address* -- the shipping street address for this transaction
    # * *:shipping_address2* -- the shipping street address second line (e.g., apartment, suite) for this transaction
    # * *:shipping_city* -- the shipping city for this transaction
    # * *:shipping_state* -- the shipping state for this transaction
    # * *:shipping_postal_code* -- the shipping zip code for this transaction
    # * *:shipping_region* -- the shipping region (e.g. county) for this transaction
    # * *:shipping_country* -- the shipping country for this transaction
    # * *:email* -- the customer email for this transaction
    # * *:csc* -- credit card security code (customer ID token or referenced transaction sale)
    # * *:invoice* -- an internal invoice number (customer ID token or referenced transaction sale)
    # * *:description* -- a description of the sale (customer ID token or referenced transaction sale)
    # * *:tax_amount* -- the amount of tax on the sale (customer ID token or referenced transaction sale)
    # * *:customer_reference_id* -- a customer reference ID (customer ID token or referenced transaction sale)
    # * *:discretionary_data* -- a hash of optional discretionary data to attach to this transaction
    # * *:return_clr* -- if set to "Y", card level results will be returned w/ the response. Card level results include whether or not the card is a consumer, purchasing, check, rewards, etc. account. Card level results are only returned with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, Global, Paymentech, and Trident networks.(customer ID token sale)
    # * *:custom_dba* -- optional value that is sent to the cardholder’s issuer and overrides the business name stored in PayTrace. Custom DBA values are only used with requests to process sales or authorizations through accounts on the TSYS/Vital, Heartland, and Trident networks (customer ID token sale)
    # * *:enable_partial_authentication* -- flag that must be set to ‘Y’ in order to support partial authorization and balance amounts in transaction responses (customer ID token sale)
    # * *:store_forward_date* -- optional future date when the transaction should be authorized and settled. Only applicable if the TranxType is STR/FWD
    def self.customer_id_store_forward(params, cfg)
      send_transaction(
        params,
        TransactionTypes::StoreForward,
        [:transaction_type, :amount, :customer_id],
        STORE_AND_FORWARD_OPTIONAL, cfg)
    end

    # See http://help.paytrace.com/api-export-transaction-information
    #
    # Exports transaction information.
    #
    # Required parameters:
    #
    # * *:transaction_id* -- a specific transaction ID to export, _or_
    # * *:start_date* -- a start date for a range of transactions to export
    # * *:end_date* -- an end date for a range of transactions to export
    # * *:transaction_type* -- the type of transaction to export (optional)
    # * *:customer_id* -- a specific customer ID to export transactions for (optional)
    # * *:transaction_user* -- the user who created the transaction (optional)
    # * *:return_bin* -- if set to 'Y', card numbers from ExportTranx and ExportCustomers requests will include the first 6 and last 4 digits of the card number (optional)
    # * *:search_text* -- text that will be searched to narrow down transaction and check results for ExportTranx and ExportCheck requests (optional)
    def self.export_by_date_range(params = {}, cfg = nil)
      response =  PayTrace::API::Gateway.send_request(EXPORT_TRANSACTIONS_METHOD, params, [:start_date, :end_date], [
        :transaction_type,
        :customer_id,
        :transaction_user,
        :return_bin,
        :search_text], cfg)
      response.parse_records(EXPORT_TRANSACTIONS_RESPONSE)
    end

    # See http://help.paytrace.com/api-export-transaction-information
    #
    # Exports transaction information.
    #
    # Required parameters:
    #
    # * *:transaction_id* -- a specific transaction ID to export, _or_
    # * *:start_date* -- a start date for a range of transactions to export
    # * *:end_date* -- an end date for a range of transactions to export
    # * *:transaction_type* -- the type of transaction to export (optional)
    # * *:customer_id* -- a specific customer ID to export transactions for (optional)
    # * *:transaction_user* -- the user who created the transaction (optional)
    # * *:return_bin* -- if set to 'Y', card numbers from ExportTranx and ExportCustomers requests will include the first 6 and last 4 digits of the card number (optional)
    # * *:search_text* -- text that will be searched to narrow down transaction and check results for ExportTranx and ExportCheck requests (optional)
    def self.export_by_id(params = {}, cfg)
      response =  PayTrace::API::Gateway.send_request(EXPORT_TRANSACTIONS_METHOD, params, [:transaction_id], [
        :transaction_type,
        :customer_id,
        :transaction_user,
        :return_bin,
        :search_text], cfg)
      response.parse_records(EXPORT_TRANSACTIONS_RESPONSE)
    end

    # See http://help.paytrace.com/api-signature-capture-image
    #
    # Attach Signature Request -- allows attaching a signature image to a transactions
    #
    # Required parameters:
    #
    # * *:transaction_id* -- the transaction ID to attach a signature image
    # * *:image_file* -- the filename of an image file to load and Base64 encode
    # * *:image_type* -- the type of image attached (e.g. "PNG", "JPG", etc.)
    def self.attach_signature_file(params = {}, cfg)
      params = params.dup
      File.open(params[:image_file], 'rb') do |file|
        params[:image_data] = Base64.encode64(file.read)
        params.delete(:image_file)
      end

      PayTrace::API::Gateway.send_request(ATTACH_SIGNATURE_METHOD, params, [:transaction_id, :image_data, :image_type], cfg)
    end

    # See http://help.paytrace.com/api-signature-capture-image
    #
    # Attach Signature Request -- allows attaching a signature image to a transactions
    #
    # Required parameters:
    #
    # * *:transaction_id* -- the transaction ID to attach a signature image
    # * *:image_data* -- the base-64 encoded image data of a signature
    # * *:image_type* -- the type of image attached (e.g. "PNG", "JPG", etc.)
    def self.attach_signature_data(params = {}, cfg)
      PayTrace::API::Gateway.send_request(ATTACH_SIGNATURE_METHOD, params, [:transaction_id, :image_data, :image_type], cfg)
    end

    # See http://help.paytrace.com/api-calculate-shipping-rates
    #
    # Calculates the estimaged shipping cost to send a package of a given weight from a source zip to a destination.
    # Returns an array of potential shippers, such as USPS, Fedex, etc., and the estimated cost to ship the package
    #
    # Required parameters:
    #
    # * *:source_zip* -- the zip code the package will be shipped from
    # * *:source_state* -- the state the package will be shipped from
    # * *:shipping_postal_code* -- the postal (zip) code the package will be shipped to
    # * *:shipping_state* -- the state the package will be shipped to
    # * *:shipping_weight* -- the weight of the package
    # * *:shippers* -- string of shipping service providers you would like shipping quotes from. String may contain USPS, FEDEX, or UPS, separated by commas, in any order or combination
    def self.calculate_shipping(params = {}, cfg)
      response = PayTrace::API::Gateway.send_request(CALCULATE_SHIPPING_COST, params, [
        :source_zip,
        :source_state,
        :shipping_postal_code,
        :shipping_state,
        :shipping_weight,
        :shippers
      ], cfg)
      response.parse_records(CALCULATE_SHIPPING_COST_RESPONSE)
    end

    # See http://help.paytrace.com/api-adding-level-3-data-to-a-visa-sale
    #
    # Level 3 data is additional information that may be applied to enrich a transaction’s reporting value to both the merchant and the customers. Generally, merchant service providers offer reduced or qualified pricing for transactions that are processed with Level 3 data.
    #
    # Level 3 data may be added to any Visa or MasterCard sale that is approved and pending settlement. Some level 3 data, specifically enhanced data such as Invoice and Customer Reference ID, may overlap with data provided with the base transaction. Enhanced data, when applied, will always overwrite such data that may already be stored with the transaction.
    #
    # Level 3 data consists of enhanced data and 1 or more line item records. This information is intended to describe the details of the transaction and the products or services rendered. However, defaults may be applied in the event that some data is missing or unknown. So, all required fields must be present, even if their values are empty. Empty values will be overwritten with PayTrace defaults.
    #
    # Please note that Visa and MasterCard each have their own requirements for level 3 data, so your application should be able to determine if the transaction being updated in a Visa or a MasterCard before formatting and sending the request. All Visa account numbers begin with “4” and contain 16 digits. All MasterCard account numbers begin with “5” and also contain 16 digits.
    #
    # Required parameters (in arguments hash):
    #
    # * *:transaction_id* -- the transaction ID to which to add this data (required)
    #
    # Optional parameters (in arguments hash):
    #
    # * *:invoice* -- invoice is the identifier for this transaction in your accounting or inventory management system
    # * *:customer_reference_id* -- customer reference ID is only used for transactions that are identified as corporate or purchasing credit cards. The customer reference ID is an identifier that your customer may ask you to provide in order to reference the transaction to their credit card statement
    # * *:tax_amount* -- portion of the original transaction amount that is tax. Must be a number that reports the tax amount of the transaction. Use -1 if the transaction is tax exempt
    # * *:national_tax* -- portion of the original transaction amount that is national tax. Generally only applicable to orders shipped to countries with a national or value added tax
    # * *:merchant_tax_id* -- merchant’s tax identifier used for tax reporting purposes
    # * *:customer_tax_id* -- customer’s tax identifier used for tax reporting purposes
    # * *:ccode* -- commodity code that generally applies to each product included in the order. Commodity codes are generally assigned by your merchant service provider
    # * *:discount* -- discount value should represent the amount discounted from the original transaction amount
    # * *:freight* -- freight value should represent the portion of the transaction amount that was generated from shipping costs
    # * *:duty* -- duty should represent any costs associated with shipping through a country’s customs
    # * *:source_zip* -- zip code that the package will be sent from
    # * *:shipping_postal_code* -- zip code where the product is delivered
    # * *:shipping_country* -- country where the product is delivered
    # * *:add_tax* -- any tax generated from freight or other services associated with the transaction
    # * *:add_tax_rate* -- rate at which additional tax was assessed
    # * *:line_items* -- see below
    #
    # The params may include a :line_items key, which should be an array of zero or more line item detail items. Each detail item is itself a parameter hash, containing any or none of the following:
    #
    # * *:ccode_li* -- the complete commodity code unique to the product referenced in this specific line item record. Commodity codes are generally assigned by your merchant service provider
    # * *:product_id* -- your unique identifier for the product
    # * *:description* -- optional text describing the transaction, products, customers, or other attributes of the transaction
    # * *:quantity* -- item count of the product in this order
    # * *:measure* -- unit of measure applied to the product and its quantity. For example, LBS/LITERS, OUNCES, etc.
    # * *:unit_cost* -- product amount per quantity
    # * *:add_tax_li* -- additional tax amount applied to the transaction applicable to this line item record
    # * *:add_tax_rate_li* -- rate at which additional tax was calculated in reference to this specific line item record
    # * *:discount_li* -- discount amount applied to the transaction amount in reference to this line item record
    # * *:amount_li* -- total amount included in the transaction amount generated from this line item record
    def self.add_level_three_visa(params = {}, cfg)
      params = params.dup # don't modify the original!

      line_items = params.delete(:line_items) || []
      PayTrace::API::Gateway.send_request(LEVEL_3_VISA_METHOD, params, [:transaction_id], [
        :invoice,
        :customer_reference_id,
        :tax_amount,
        :national_tax,
        :merchant_tax_id,
        :customer_tax_id,
        :ccode,
        :discount,
        :freight,
        :duty,
        :source_zip,
        :shipping_postal_code,
        :shipping_country,
        :add_tax,
        :add_tax_rate
        ], cfg) do |request|

        line_items.each do |li|
          missing, extra = PayTrace::API::Request.process_param_list([
              :ccode_li,
              :product_id,
              :description,
              :quantity,
              :measure,
              :unit_cost,
              :add_tax_li,
              :add_tax_rate_li,
              :discount_li,
              :amount_li
            ], li)
          if extra.any?
            raise PayTrace::Exceptions::ValidationError.new("The following line-item parameters are unknown: #{extra.to_s}")
          end
          request.set_multivalue(:line_item, li)
        end
      end
    end

    # See http://help.paytrace.com/api-adding-level-3-data-to-a-mastercard-sale
    #
    # Level 3 data is additional information that may be applied to enrich a transaction’s reporting value to both the merchant and the customers. Generally, merchant service providers offer reduced or qualified pricing for transactions that are processed with Level 3 data.
    #
    # Level 3 data may be added to any Visa or MasterCard sale that is approved and pending settlement. Some level 3 data, specifically enhanced data such as Invoice and Customer Reference ID, may overlap with data provided with the base transaction. Enhanced data, when applied, will always overwrite such data that may already be stored with the transaction.
    #
    # Level 3 data consists of enhanced data and 1 or more line item records. This information is intended to describe the details of the transaction and the products or services rendered. However, defaults may be applied in the event that some data is missing or unknown. So, all required fields must be present, even if their values are empty. Empty values will be overwritten with PayTrace defaults.
    #
    # Please note that Visa and MasterCard each have their own requirements for level 3 data, so your application should be able to determine if the transaction being updated in a Visa or a MasterCard before formatting and sending the request. All Visa account numbers begin with “4” and contain 16 digits. All MasterCard account numbers begin with “5” and also contain 16 digits.
    #
    # Required parameters (in arguments hash):
    #
    # * *:transaction_id* -- the transaction ID to which to add this data (required)
    #
    # Optional parameters (in arguments hash):
    #
    # * *:invoice* -- invoice is the identifier for this transaction in your accounting or inventory management system
    # * *:customer_reference_id* -- customer reference ID is only used for transactions that are identified as corporate or purchasing credit cards. The customer reference ID is an identifier that your customer may ask you to provide in order to reference the transaction to their credit card statement
    # * *:tax_amount* -- portion of the original transaction amount that is tax. Must be a number that reports the tax amount of the transaction. Use -1 if the transaction is tax exempt
    # * *:national_tax* -- portion of the original transaction amount that is national tax. Generally only applicable to orders shipped to countries with a national or value added tax
    # * *:ccode* -- commodity code that generally applies to each product included in the order. Commodity codes are generally assigned by your merchant service provider
    # * *:freight* -- freight value should represent the portion of the transaction amount that was generated from shipping costs
    # * *:duty* -- duty should represent any costs associated with shipping through a country’s customs
    # * *:source_zip* -- zip code that the package will be sent from
    # * *:shipping_postal_code* -- zip code where the product is delivered
    # * *:shipping_country* -- country where the product is delivered
    # * *:add_tax* -- any tax generated from freight or other services associated with the transaction
    # * *:additional_tax_included* -- a flag used to indicate where additional tax was included in this transaction. Set to Y if additional tax was included and N if no additional tax was applied
    # * *:line_items* -- see below
    #
    # The params may include a :line_items key, which should be an array of zero or more line item detail items. Each detail item is itself a parameter hash, containing any or none of the following:
    #
    # * *:product_id* -- your unique identifier for the product
    # * *:description* -- optional text describing the transaction, products, customers, or other attributes of the transaction
    # * *:quantity* -- item count of the product in this order
    # * *:measure* -- unit of measure applied to the product and its quantity. For example, LBS/LITERS, OUNCES, etc.
    # * *:merchant_tax_id* -- merchant’s tax identifier used for tax reporting purposes
    # * *:unit_cost* -- product amount per quantity
    # * *:additional_tax_included_li* -- descriptor used to describe additional tax that is applied to the transaction amount in reference to this specific line item
    # * *:add_tax_li* -- additional tax amount applied to the transaction applicable to this line item record
    # * *:add_tax_rate_li* -- rate at which additional tax was calculated in reference to this specific line item record
    # * *:amount_li* -- total amount included in the transaction amount generated from this line item record
    # * *:discount_included* -- flag used to indicate whether discount was applied to the transaction amount in reference to this specific line item record
    # * *:line_item_is_gross* -- flag used to indicate whether the line item amount is net or gross to specify whether the line item amount includes tax. Possible values are Y (includes tax) and N (does not include tax)
    # * *:is_debit_or_credit* -- flag used to determine whether the line item amount was a debit or a credit to the customer. Generally always a debit or a factor that increased the transaction amount. Possible values are D (net is a debit) and C (net is a credit)
    # * *:discount_li* -- discount amount applied to the transaction amount in reference to this line item record
    # * *:discount_rate* -- rate at which discount was applied to the transaction in reference to this specific line item
    def self.add_level_three_mc(params = {}, cfg)
      params = params.dup # don't modify the original!

      line_items = params.delete(:line_items) || []
      response = PayTrace::API::Gateway.send_request(LEVEL_3_MC_METHOD, params, [:transaction_id], [
        :invoice,
        :customer_reference_id,
        :tax_amount,
        :national_tax,
        :freight,
        :duty,
        :source_zip,
        :shipping_postal_code,
        :shipping_country,
        :add_tax,
        :additional_tax_included
        ]) do |request|

        line_items.each do |li|
          missing, extra = PayTrace::API::Request.process_param_list([
              :product_id,
              :description,
              :quantity,
              :measure,
              :merchant_tax_id,
              :unit_cost,
              :add_tax_li,
              :add_tax_rate_li,
              :additional_tax_included_li,
              :amount_li,
              :discount_included,
              :discount_li,
              :discount_rate,
              :is_debit_or_credit,
              :line_item_is_gross
            ], li)
          if extra.any?
            raise PayTrace::Exceptions::ValidationError.new("The following line-item parameters are unknown: #{extra.to_s}")
          end
          request.set_multivalue(:line_item, li)
        end
      end
    end

    # See http://help.paytrace.com/api-settling-transactions
    #
    # Transactions processed through merchant accounts that are set up on the TSYS/Vital network or other terminal-based networks may initiate the settlement of batches through the PayTrace API.
    #
    # No parameters are required.
    def self.settle_transactions(params = {}, cfg)
      PayTrace::API::Gateway.send_request(SETTLE_TRANSACTION_METHOD, [], {})
    end

    # See http://help.paytrace.com/api-adjusting-transaction-amounts
    #
    # Transactions processed through merchant accounts that are set up on the TSYS/Vital network or other terminal-based networks may adjust transaction amounts to any amount that is less than or equal to the original transaction amount and greater than zero. A transaction cannot be adjusted to more than 30% above its authorized amount. Amounts may be adjusted for the following transaction conditions:
    #
    # * Approved Sale that is not yet settled
    # * Forced Sale that is not yet settled
    # * Authorization that is approved and not yet settled
    # * Refund that is not yet settled
    #
    # Please note that amounts for cash advance transaction may also not be adjusted.
    #
    # Required parameters:
    #
    # *:transaction_id* -- a unique identifier for each transaction in the PayTrace system. This value is returned in the TRANSACTIONID parameter of an API response and will consequently be included in requests to email receipts, void transactions, add level 3 data, etc
    # *:amount* -- dollar amount of the transaction. Must be a positive number up to two decimal places
    def self.adjust_amount(params = {}, cfg)
      PayTrace::API::Gateway.send_request(ADJUST_AMOUNT_METHOD, params, [:transaction_id, :amount])
    end

    # private helper method to DRY things up a bit
    def self.send_transaction(params, type, required, optional, cfg)
      PayTrace::API::Gateway.send_request(
        TRANSACTION_METHOD,
        {transaction_type: type}.merge(params),
        required,
        optional, cfg)
    end

    private_class_method :send_transaction
  end

  # enumeration of transaction subtypes
  module TransactionTypes
    SALE = "SALE"
    Authorization = "Authorization"
    Refund = "Refund"
    Void = "Void"
    ForcedSale = "Force"
    Capture = "Capture"
    StoreForward ="Str/FWD"
  end

end
