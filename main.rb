require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :james => 'james' 

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_POT_AMOUNT = 500

helpers do
  def calculate_total(cards)
    arr = cards.map{|element| element[1]}

    total = 0
    arr.each do |a|
      if a == "A"
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    arr.select{|element| element == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end

    total
  end

  def card_image(card) #['S', '3']
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'S' then 'spades'
      when 'C' then 'clubs'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @play_again = true
    show_hit_ot_stay_buttons = false
    session[:player_pot] = session[:player_pot] + session[:player_bet]
    @winner = "<strong>Congratulations, #{session[:player_name]}! You win!</strong> #{msg}"
  end

  def loser!(msg)
    @play_again = true
    @show_hit_ot_stay_buttons = false
    session[:player_pot] = session[:player_pot] - session[:player_bet]
    @loser = "<strong>Sorry, #{session[:player_name]}. You lost.</strong> #{msg}"
  end

  def tie!(msg)
    @play_again = true
    show_hit_ot_stay_buttons = false
    @winner = "<strong>Push!</strong> #{msg}"
  end
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end  
end

before do
  @show_hit_ot_stay_buttons = true
end

get '/new_player' do
  session[:player_pot] = INITIAL_POT_AMOUNT
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Name is required"
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
end 

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @error = "Please make a bet."
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot].to_i
    @error = "Bet amount cannot exceed currrent player pot ($#{session[:player_pot]})"
    halt erb(:bet)
  elsif params[:bet_amount].to_i < 0
    @error = "Please make a valid bet."
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]

  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    winner!("You hit blackjack!")
    @show_hit_ot_stay_buttons = false
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])
  if player_total == BLACKJACK_AMOUNT
    winner!("You hit blackjack!")
  elsif player_total > BLACKJACK_AMOUNT
    loser!("You busted at #{player_total}.")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "You have chosen to stay."  
  @show_hit_ot_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_ot_stay_buttons = false

  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT
    loser!("The dealer hit blackjack!")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("The dealer busted at #{dealer_total}")
  elsif dealer_total >= DEALER_MIN_HIT
    redirect '/game/compare'
  else
    @show_dealer_hit_button = true
  end

    erb :game, layout: false      
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_ot_stay_buttons = false
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("The dealer has #{dealer_total} and you have #{player_total}.")
  elsif player_total > dealer_total
    winner!("You have #{player_total} and the dealer has #{dealer_total}.")
  else
     tie!("You both have #{player_total}")
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end
