require 'sinatra/base'
require 'ecdsa'
require 'securerandom'
require 'sinatra/contrib/all'
require 'base64'

$users = {'admin' => 'Imp0ssibl3'
         } 
$group = ECDSA::Group::Secp256k1
$private_key = 1 + SecureRandom.random_number($group.order - 1)
$public_key = $group.generator.multiply_by_scalar($private_key)

class SuperSecret < Sinatra::Base
  set :public_folder, File.join(File.dirname(__FILE__), 'public')
  set :views, File.join(File.dirname(__FILE__), 'views')
  register Sinatra::Contrib

  def verify?(str,signature)
    digest = Digest::SHA256.digest(str)
    ECDSA.valid_signature?($public_key, digest, signature)
  end
  def sign(str)
    signature = ECDSA.sign($group, $private_key, Digest::SHA256.digest(str) , str.size)
  end

  helpers do
    alias_method :h, :escape_html
  end
  
  get '/' do
    if cookies[:secure]
      user, sig = Base64.decode64(cookies[:secure]).split("--")
      return erb :index unless sig and user
      if verify?(user,ECDSA::Format::SignatureDerString.decode(sig)) 
        #ECDSA.valid_signature?($public_key,Digest::SHA256.digest("admin"),ECDSA::Format::SignatureDerString.decode(sig))
        @user = user
        if @user == "admin"
          return erb :admin
        end
      end
      return erb :index
    else 
      return erb :index
    end
  end 

  post '/register' do
    user = params['username'].to_s[0..20]
    return "Invalid username" if $users[user]
    password = Digest::SHA256.hexdigest(params['password'].to_s[0..20])
    $users[user] = password
    sig = sign(user)
    cookies[:secure] = Base64.strict_encode64(user+"--"+ECDSA::Format::SignatureDerString.encode(sig)) 
    redirect '/'
  end
   
  post '/login' do
    user = params['username'].to_s[0..20]
    password = Digest::SHA256.hexdigest(params['password'].to_s[0..20])
    if $users[user] and $users[user] == password
      sig = sign(user)
      cookies[:secure] = Base64.strict_encode64(user+"--"+ECDSA::Format::SignatureDerString.encode(sig)) 
    else
      return "Invalid username or password"
    end
    redirect '/'
  end
  
end