class CheckoutsController < ApplicationController
  include CurrentCart
  before_action :set_cart
  before_action :ensure_cart_isnt_empty, only: [:new]

  def new
    @checkout = Checkout.new(cart: @cart)
    @client_secret = @checkout.create_payment_intent
  end

  def create
    @checkout = Checkout.new(cart: @cart, payment_intent_id: params[:payment_intent_id])

    begin
      if @checkout.process_payment
        order = @checkout.create_order(current_user)
        @cart.destroy
        session[:cart_id] = nil
        render json: { success: true, order_id: order.id }
      else
        render json: { success: false, error: "Payment processing failed" }, status: :unprocessable_entity
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Payment processing error: #{e.full_message}"
      render json: { success: false, error: "An unexpected error occurred" }, status: :internal_server_error
    end
  end

  private

  def ensure_cart_isnt_empty
    if @cart.cart_items.empty?
      redirect_to root_path, alert: "Your cart is empty."
    end
  end
end