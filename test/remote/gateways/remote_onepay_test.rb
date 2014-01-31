require 'test_helper'

class RemoteOnepayTest < Test::Unit::TestCase


  def setup
    @gateway = OnepayGateway.new(fixtures(:onepay))

    @amount = 100
    @credit_card = credit_card('1111111111111111')
    @declined_card = credit_card('2222222222222222')

    @options = {
      :ip => '127.0.0.1',
      :order_id => '1',
      :billing_address => address({ :number => 123, :zip => '41180710' }),
      :description => 'Store Purchase',
      :cpf => '02183345594',
      :birth_date => '1990-01-01'
    }

    @recurring_options = @options.merge({
        :frequency => 0,
        :day => 1
    })
  end

  def successful_purchase_and_approved_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'PROCESSING', response.message
    assert void = @gateway.void(response.authorization, @options)
    assert_success void
    assert_equal 'APPROVED', void.message
  end

  def successful_purchase_and_rejected_void
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_success response
    assert_equal 'PROCESSING', response.message
    assert void = @gateway.void(response.authorization, @options)
    assert_failure void
    assert_equal 'DECLINED', void.message
  end

  def successful_purchase_and_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'PROCESSING', response.message

    assert void = @gateway.void(response.authorization, @options)
    assert_success void
    assert_equal 'APPROVED', void.message

    assert refund = @gateway.refund(response.authorization, @options)
    assert_success refund
    assert_equal 'APPROVED', refund.message
  end

  def test_successful_recurring
    assert response = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_success response
  end



  #def test_invalid_login
  #  gateway = OnepayGateway.new(
  #              :login => '',
  #              :password => '',
  #              :service  => '',
  #              :portal => ''
  #            )
  #  assert response = gateway.purchase(@amount, @credit_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  #end
end
