module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OnepayGateway < Gateway
      self.test_url = self.live_url = 'https://ssl.onepay.com.br/api/'

      self.supported_countries = ['BR']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.onepay.com.br/'
      self.display_name = 'OnePay'
      self.money_format = :cents
      self.default_currency = 'BRL'

      PROCESSING, FRAUD, RESUBMIT, DECLINED, APPROVED, ERROR  = 0, 1, 2, 3, 4, 5

      def initialize(options = {})
        requires!(options, :login, :password, :service, :portal)
        super
      end

      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}

        add_customer_data(post, creditcard, options)
        add_invoice(post, money, options)
        add_creditcard(post, creditcard)

        commit(:do_billing, post)
      end

      def void(identification, options = {})
        post = {}

        post[:cpf] = options[:cpf]
        post[:requestOrderId] = identification

        commit(:check_order, post)
      end

      def refund(identification, options = {})
        post = {}

        post[:cpf] = options[:cpf]
        post[:requestOrderId] = identification

        refund_commit(:do_reverse_order, post)
      end

      def recurring(money, creditcard, options = {})
        requires!(options, :order_id, :frequency, :day)

        post = {}

        add_customer_data(post, creditcard, options)
        post[:amount] = amount(money)

        recurring_commit(:add_periodic, post)
      end

      private

      def create_customer(options, creditcard)
        post = {}

        add_address(post, options)
        add_customer_creditcard(post, creditcard)
        post[:cpf]          = options[:cpf]
        post[:birthDate]    = options[:birth_date]

        customer_commit(:register_user, post)
      end

      def add_customer_data(post, creditcard, options)
        customer = create_customer(options, creditcard)
        if customer.success?
          post[:cpf] = options[:cpf]
          post[:browserIp] = options[:ip]
        else
          raise CustomerError, customer.message
        end
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        post[:street]         = address[:address1] unless address[:address1].nil?
        post[:complement]     = address[:address2] unless address[:address2].nil?
        post[:addressZipCode] = address[:zip].to_i
        post[:addressNumber]  = address[:number]
      end

      def add_invoice(post, money, options)
        post[:externalId] = options[:order_id]
        post[:amount]     = amount(money)
      end

      def add_customer_creditcard(post, creditcard)
        post[:cc]       = creditcard.number
        post[:yy]       = creditcard.year.to_s[2..-1]
        post[:mm]       = "%02d" % creditcard.month
        post[:name]     = creditcard.first_name
        post[:surname]  = creditcard.last_name
      end

      def add_creditcard(post, creditcard)
        post[:cvv2]     = creditcard.verification_value
      end

      def parse(body)
        JSON.parse(body, :symbolize_names => true)
      end

      def customer_commit(action, parameters)
        url         = self.live_url + action.to_s
        data        = ssl_post url, post_data(parameters)
        response    = parse(data)

        message     = response[:errorId].to_i == 0 ? "Customer exist." : response[:errorDescription]
        success     = response[:errorId].to_i == 0

        Response.new(success, message, response,
          :test => test?
        )
      end

      def refund_commit(action, parameters)
        url           = self.live_url + action.to_s
        data          = ssl_post url, post_data(parameters)
        response      = parse(data)

        message = response[:requestStatus].to_i == 0 ? "DECLINED" : "APPROVED"

        Response.new(response[:requestStatus].to_i == 1, message, response,
                     :authorization => response[:requestOrderId]
        )
      end

      def recurring_commit(action, parameters)
        url           = self.live_url + action.to_s
        data          = ssl_post url, post_data(parameters)
        response      = parse(data)

        message = response[:userSubscribed].to_i == 0 ? "DECLINED" : "APPROVED"

        Response.new(response[:userSubscribed].to_i == 1, message, response,
                     :authorization => response[:orderId]
        )
      end

      def commit(action, parameters)
        url           = self.live_url + action.to_s
        data          = ssl_post url, post_data(parameters)
        response      = parse(data)

        message = message_from(response)

        Response.new(success?(response), message, response,
                     :fraud_review => fraud_review?(response),
                     :authorization => response[:requestOrderId]
        )
      end

      def success?(response)
        response[:errorId].to_i == 0 && [PROCESSING, APPROVED].include?(response[:requestStatus])
      end

      def fraud_review?(response)
        !response[:requestStatus].nil? && response[:requestStatus].to_i == FRAUD
      end

      def message_from(response)
        return response[:errorDescription] if response[:errorId].to_i != 0

        case response[:requestStatus].to_i
          when PROCESSING
            "PROCESSING"
          when FRAUD
            "FRAUD"
          when RESUBMIT
            "RESUBMIT"
          when DECLINED
            "DECLINED"
          when APPROVED
            "APPROVED"
          when ERROR
            response[:errorDescription]
        end
      end

      def post_data(parameters = {})
        parameters.update(
            :type => :json,
            :username => @options[:login],
            :psw => @options[:password],
            :service => @options[:service],
            :portal => @options[:portal]
        )

        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      class CustomerError < ::Exception
      end
    end
  end
end

