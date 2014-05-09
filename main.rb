require 'rubygems'
require 'sinatra'

set :sessions, true

helpers do

  def bet_validation(bet)
    if bet.to_i < 5
      @error = "a player has to bet minimum 5 or more."
      halt erb(:welcome)
    elsif bet.to_i > session[:player_balance]
      @error = "betting no more than player's balance."
      halt erb(:welcome)
    end
  end

  def name_validation(name)
    if name.empty?
      @error = "a player_name is required"
      halt erb(:new_user)
    end
  end

  def count_points(cards)
    # total = count_points(session[:player_hand])

    arr = cards.map{|e| e[1] }
    total = 0
    
    arr.each do |value|
      if value == "A"
        total += 11
      elsif value.to_i == 0 # J, Q, K
        total += 10
      else
        total += value.to_i
      end
    end

    #correct for Aces
    arr.select{|e| e == "A"}.count.times do
      total -= 10 if total > 21
    end

    total
  end

  def card_file_name(card)
    "#{display(card[0]).downcase}_#{(card[1].to_i == 0 ? display(card[1]) : card[1]).downcase}"
  end

  def card_full_name(card)
    "#{display(card[1])} of #{display(card[0])}"
  end

  def display(suit_or_rank)
    word_hsh = {"H"=>"Hearts", "D"=>"Diamonds", "C"=>"Clubs", "S"=>"Spades", "2"=>"Two", "3"=>"Three", "4"=>"Four", "5"=>"Five", "6"=>"Six", "7"=>"Seven", "8"=>"Eight", "9"=>"Nine", "10"=>"Ten", "A"=>"Ace", "Q"=>"Queen", "K"=>"King", "J"=>"Jack"}
    word_hsh[suit_or_rank]
  end

  def blackjack?(cards)
    count_points(cards) == 21 && cards.count == 2
  end 

  def busted?(cards)
    count_points(cards) > 21
  end

  def conclusive
    case session[:closing]
    when 'player_busted'
      @alert = "#{session[:user_name]} Busts"
      @player_turn = true
      @win_much = session[:bet_much] * -1
    when 'both_blackjack'
      @alert = "Dealer Blackjack - Round Push."
      @win_much = 0
    when 'player_blackjack'
      @alert = "#{session[:user_name]} won Black Jack!"
      @win_much = session[:bet_much] * 2
    when 'dealer_blackjack'
      @alert = "Dealer Black Jack - #{session[:user_name]} Lost"
      @win_much = session[:bet_much] * -1
    when 'dealer_busted'
      @alert = "Dealer Busts"
      @win_much = session[:bet_much] * 1
    when 'must_compare'
      compare(count_points(session[:player_hand]),count_points(session[:dealer_hand]))
    end
  end

  def compare(player_total, dealer_total)
    if player_total > dealer_total
      @alert = "Dealer Stay - #{session[:user_name]} Won"
      @win_much = session[:bet_much] * 1
    elsif player_total < dealer_total
      @alert = "Dealer Stay - #{session[:user_name]} Lost"
      @win_much = session[:bet_much] * -1
    else # if tie
      @alert = "Dealer Stay - Round Push."
      @win_much = 0
    end
  end

end # end of helpers

before do
  @show_navbar = true
  @player_turn = false
end

get '/' do
  if session[:user_name]
    redirect '/welcome' 
  else
    redirect '/new_user'
  end
end

get '/new_user' do
  erb :new_user
end

post '/new_user' do
  name_validation(params[:user_name].strip)
  session[:user_name] = params[:user_name].capitalize
  redirect '/welcome'
end

get '/welcome' do
  @success = "Hello #{session[:user_name]}"
  session[:player_balance] ||= 500
  erb :welcome
end

post '/welcome' do
  bet_validation(params[:bet_much])
  session[:bet_much] = 0
  session[:bet_much] = params[:bet_much].to_i
  redirect '/game'
end

get '/game' do
  session[:deck] = ['D','S','H','C'].product(['2','3','4','5','6','7','8','9','10','A','Q','K','J']).shuffle!
  session[:player_hand] = []
  session[:dealer_hand] = []
  session[:player_hand] << session[:deck].pop
  session[:dealer_hand] << session[:deck].pop
  session[:player_hand] << session[:deck].pop
  session[:dealer_hand] << session[:deck].pop

  if blackjack?(session[:player_hand])
    session[:closing] = 'player_blackjack'
    redirect '/dealer'
  else
    @player_turn = true
    erb :game 
  end
end

post '/game' do
  if params[:hit_or_stay] == 'hit'
    redirect '/hit'
  else 
    redirect '/dealer' # player stay
  end
end

get '/hit' do # player hit
  @player_turn = true
  session[:player_hand] << session[:deck].pop

  if busted?(session[:player_hand])
    session[:closing] = 'player_busted'
    redirect '/conclude'
  else
    erb :game
  end
end

get '/dealer' do
  if blackjack?(session[:dealer_hand])
    if blackjack?(session[:player_hand])
      session[:closing] = 'both_blackjack'
    else
      session[:closing] = 'dealer_blackjack'
    end
  else
    if blackjack?(session[:player_hand])
      session[:closing] = 'player_blackjack'
    else
      while count_points(session[:dealer_hand]) < 17 # dealer hit
        session[:dealer_hand] << session[:deck].pop
        if busted?(session[:dealer_hand])
          session[:closing] = 'dealer_busted'
          redirect '/conclude'
        end  
      end
      session[:closing] = 'must_compare' # dealer stay
    end
  end
  redirect '/conclude'
end

get '/leave' do
  session.clear
  redirect '/'
end

post '/new_round' do
  if params[:new_round] == 'continue'
    session[:player_balance] = session[:conclude_balance]
    redirect '/welcome'
  else
    redirect '/leave'
  end
end

get '/conclude' do
  @win_much = 0
  conclusive
  session[:conclude_balance] = session[:player_balance] + @win_much
  erb :conclude
end